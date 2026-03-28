public with sharing class LeadConversionProcessor {

    // wrapper class
    public class LeadDataWrapper {
        @invocableVariable
        public Id leadId;

        @invocableVariable
        public String leadEmail;

        @invocableVariable
        public String accountName;

        @invocableVariable
        public String contactFirstName;

        @invocableVariable
        public String contactLastName;

        @invocableVariable
        public String opportunityName;

        @invocableVariable
        public Boolean createOpportunityFlag;
    }


    // wrapper class to bind existing records
    private class ExistingDataWrapper {
        public Map<String, Id> accountNameToIdMap;
        public Map<Id, Contact> contactAccountIdToContactMap;
        public Map<Id, Opportunity> opportunityAccountIdToOpportunityMap;

        // constructor
        public ExistingDataWrapper(){
            this.accountNameToIdMap = new Map<String, Id>();
            this.contactAccountIdToContactMap = new Map<Id, Contact>();
            this.opportunityAccountIdToOpportunityMap = new Map<Id, Opportunity>();
        }
    }
    
    // this method only accecpts a collection variable as parameter
    @invocableMethod(label= 'Process Lead Conversion Data')
    public static void processConversionData(List<LeadDataWrapper> leadDataWrapperInfo) {
        
        // checking for null values
        if(leadDataWrapperInfo == null || leadDataWrapperInfo.isEmpty()){
            return;
        }

        Set<String> accountNames = new Set<String>();
        Set<String> contactFirstNames = new Set<String>();
        Set<String> contactLastNames = new Set<String>();
        Set<String> contactEmails = new Set<String>();

        ExistingDataWrapper existingDataWrapperInfo = new ExistingDataWrapper();

        for(LeadDataWrapper ldw : leadDataWrapperInfo){
            // collecting values for duplicate check
            accountNames.add(ldw.accountName);
            contactFirstNames.add(ldw.contactFirstName);
            contactLastNames.add(ldw.contactLastName);
            contactEmails.add(ldw.leadEmail);
        }

        // checking for duplicate account
        for(Account existingAcc : [SELECT Id, Name FROM Account
                                    WHERE Name IN: accountNames
                                    WITH USER_MODE]){
                                        
                                        // collecting the existing account ids
                                        if(!existingDataWrapperInfo.accountNameToIdMap.containsKey(existingAcc.Name)){
                                            existingDataWrapperInfo.accountNameToIdMap.put(existingAcc.Name, existingAcc.Id);
                                        }
                                    }

        if(!existingDataWrapperInfo.accountNameToIdMap.isEmpty()){
            // checking for duplicate contacts associated to the account
            for(Contact existingCon : [SELECT Id, FirstName, LastName, Email, AccountId FROM Contact
                                        WHERE AccountId IN: existingDataWrapperInfo.accountNameToIdMap.values()
                                        AND FirstName IN: contactFirstNames
                                        AND LastName IN: contactLastNames
                                        AND Email IN: contactEmails
                                        WITH USER_MODE]){
                                                
                                            // collecting the existing contact ids
                                            if(!existingDataWrapperInfo.contactAccountIdToContactMap.containsKey(existingCon.AccountId)){
                                                existingDataWrapperInfo.contactAccountIdToContactMap.put(existingCon.AccountId, existingCon);
                                            }
                                        }

            // checking for available opportunities with duplicate name
            for(Opportunity existingOppo : [SELECT Id, Name, AccountId FROM Opportunity
                                            WHERE AccountId IN: existingDataWrapperInfo.accountNameToIdMap.values() 
                                            WITH USER_MODE]){

                                                // collecting the existing opportunities ids
                                                if(!existingDataWrapperInfo.opportunityAccountIdToOpportunityMap.containsKey(existingOppo.AccountId)){
                                                    existingDataWrapperInfo.opportunityAccountIdToOpportunityMap.put(existingOppo.AccountId, existingOppo);
                                                }
                                            }
                                        }        
        // calling lead conveter
        leadConverter(leadDataWrapperInfo, existingDataWrapperInfo);
    }

    // convert leads
    public static void leadConverter(List<LeadDataWrapper> leadDataWrapperInfo,  ExistingDataWrapper existingDataWrapperInfo) {

        LeadStatus leadStatusName = [SELECT Id, ApiName FROM LeadStatus
                                     WHERE isConverted = true
                                     WITH USER_MODE
                                     LIMIT 1];
    
        List<Database.LeadConvert> leadConvertList = new List<Database.LeadConvert>();

        // converting leads
        for(LeadDataWrapper ldw : leadDataWrapperInfo){

            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(ldw.leadId);
            lc.setConvertedStatus(leadStatusName.ApiName);

            if(ldw.createOpportunityFlag == true){
                lc.setDoNotCreateOpportunity(false);

                // setting opportunity name
                if(ldw.opportunityName != null){
                    lc.setOpportunityName(ldw.opportunityName);
                }
            } else {
                lc.setDoNotCreateOpportunity(true);
            }

            if(!existingDataWrapperInfo.accountNameToIdMap.isEmpty()
                && existingDataWrapperInfo.accountNameToIdMap.containsKey(ldw.accountName)){
                Id accId = existingDataWrapperInfo.accountNameToIdMap.get(ldw.accountName);
                lc.setAccountId(accId);

                // merge opportunity if exists
                if(!existingDataWrapperInfo.opportunityAccountIdToOpportunityMap.isEmpty()
                    && existingDataWrapperInfo.opportunityAccountIdToOpportunityMap.containsKey(accId)){
                    lc.setOpportunityId(existingDataWrapperInfo.opportunityAccountIdToOpportunityMap.get(accId).Id);
                }

                // merge contact if exists
                if(!existingDataWrapperInfo.contactAccountIdToContactMap.isEmpty()
                    && existingDataWrapperInfo.contactAccountIdToContactMap.containsKey(accId)){
                    lc.setContactId(existingDataWrapperInfo.contactAccountIdToContactMap.get(accId).Id);
                }
            }

            // collecting all the conversion instances
            leadConvertList.add(lc);
        }

        // converting all leads
        if(!leadConvertList.isEmpty()){
            List<Database.LeadConvertResult> result = Database.convertLead(leadConvertList, false);

            Map<Id, Id> convertedLeadIdToOpportunityIdMap = new Map<Id, Id>();

            for(Database.LeadConvertResult rs : result){
                if(rs.isSuccess()){
                    System.debug('Lead converted successfully');

                    // processing for opportunity product creation
                    if(!convertedLeadIdToOpportunityIdMap.containsKey(rs.getLeadId())){
                        convertedLeadIdToOpportunityIdMap.put(rs.getLeadId(), rs.getOpportunityId());
                    }

                    // calling the opportunity product processor class
                    if(!convertedLeadIdToOpportunityIdMap.isEmpty()){
                        OpportunityProductProcessor.createOpportunityProduct(convertedLeadIdToOpportunityIdMap);
                    }
                    
                } else {
                    for(Database.Error err : rs.getErrors()){
                        System.debug('Error while converting the lead : ' + err.getMessage());
                    }
                }
            }
        }
    }
}