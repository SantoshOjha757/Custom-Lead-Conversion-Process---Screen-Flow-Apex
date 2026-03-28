public with sharing class OpportunityProductProcessor {

    @future
    public static void createOpportunityProduct(Map<Id, Id> convertedLeadIdToOpportunityIdMap) {

        if(convertedLeadIdToOpportunityIdMap != null && !convertedLeadIdToOpportunityIdMap.isEmpty()){

            
            // getting the lead products
            List<Lead_Product__c> leadProdList = [SELECT Id, Lead_Id__c, Product_Id__c, Price_Book_Id__c, Quantity__c
                                                    FROM Lead_Product__c
                                                    WHERE Lead_Id__c =: convertedLeadIdToOpportunityIdMap.keySet()
                                                    WITH USER_MODE];
            
            Set<Id> prod2Ids = new Set<Id>();
            Set<Id> priceBookIds = new Set<Id>();
            Map<Id, Id> leadIdToPriceBookIdMap = new Map<Id, Id>();

            if(!leadProdList.isEmpty()){
                for(Lead_Product__c leadProd : leadProdList){
    
                    // collecting the lead Ids with pricebook Ids
                    if(!leadIdToPriceBookIdMap.containsKey(leadProd.Lead_Id__c)){
                        leadIdToPriceBookIdMap.put(leadProd.Lead_Id__c, leadProd.Price_Book_Id__c);
                    }
    
                    // collecting the product Ids
                    prod2Ids.add(leadProd.Product_Id__c);
                }
            }

            List<Opportunity> convertedOpportunityListToUpdate = new List<Opportunity>();

            // assigning pricebook id to the converted opportunity from lead products of the same lead
            if(!leadIdToPriceBookIdMap.isEmpty()){
                for(Id eachLeadId : leadIdToPriceBookIdMap.keySet()){
                    if(convertedLeadIdToOpportunityIdMap.containsKey(eachLeadId)){
                        convertedOpportunityListToUpdate.add(
                            new Opportunity(
                                Id = convertedLeadIdToOpportunityIdMap.get(eachLeadId),
                                Pricebook2Id = leadIdToPriceBookIdMap.get(eachLeadId)
                            )
                        );
                        // collecing the priceBook Ids for against the lead and updated opportunity
                        priceBookIds.add(leadIdToPriceBookIdMap.get(eachLeadId));
                    }
                }
            }

            // updating the converted opportunity
            if(!convertedOpportunityListToUpdate.isEmpty()){
                update convertedOpportunityListToUpdate;
            }

            Map<Id, PricebookEntry> productIdToPricebookEntryMap = new Map<Id, PricebookEntry>();

            // getting the pricebook entry
            if(prod2Ids != null){
                for(PricebookEntry pbe : [SELECT Id, Product2Id, pricebook2Id, UnitPrice FROM PricebookEntry
                                            WHERE Product2Id IN: prod2Ids
                                            AND pricebook2Id =: priceBookIds
                                            WITH USER_MODE]){

                                                // collecting the pricebook with pricebook entry
                                                productIdToPricebookEntryMap.put(pbe.Product2Id, pbe);
                                            }
            }

            List<OpportunityLineItem> oppLineItemListToInsert = new List<OpportunityLineItem>();
           
            // preparing the opportunity products
            if(!productIdToPricebookEntryMap.isEmpty()){
                for(Lead_Product__c lp : leadProdList){
                    if(productIdToPricebookEntryMap.containsKey(lp.Product_Id__c) && convertedLeadIdToOpportunityIdMap.containsKey(lp.Lead_Id__c)){
                        oppLineItemListToInsert.add(
                            new OpportunityLineItem(
                                Product2Id = productIdToPricebookEntryMap.get(lp.Product_Id__c).Product2Id,
                                PricebookEntryId = productIdToPricebookEntryMap.get(lp.Product_Id__c).Id,
                                OpportunityId = convertedLeadIdToOpportunityIdMap.get(lp.Lead_Id__c),
                                UnitPrice = productIdToPricebookEntryMap.get(lp.Product_Id__c).UnitPrice,
                                Quantity = lp.Quantity__c
                            )
                        );
                    }
                }
            }

            // inserting opportunity product
            if(!oppLineItemListToInsert.isEmpty()){
                insert oppLineItemListToInsert;
            }
        }
    }
}