@RestResource(urlMapping='/AccountServiceCustom/')
global with sharing class AccountRestService {
    @httpPut
    global static void accountWorkerUpdate() {
        RestRequest accReq = RestContext.request;
        String reqBody = accReq.requestBody.toString();

        // deserialising the request body to list of objects
        List<Account> reqBodyList = (List<Account>)JSON.deserialize(reqBody, List<Account>.class);

        Map<Id, Account> accMap = new Map<Id, Account>();

        // extracting the accounts
        if(!reqBodyList.isEmpty()){
            for(Account eachAcc : reqBodyList){
                if(eachAcc.Id != null && eachAcc.Name != null && eachAcc.AnnualRevenue != null){
                    if(!accMap.containsKey(eachAcc.Id)){
                        accMap.put(eachAcc.Id, eachAcc);
                    }
                }
            }
        }

        // getting the existing accounts
        List<Account> accWorkList = new List<Account>(
            [SELECT Id, external_Id__c FROM Account WHERE external_Id__c IN: accMap.keySet()]
        );

        List<Account> accListToUpsert = new List<Account>();

        if(!accWorkList.isEmpty()){
            // updating the existing accounts
            for(Account acc : accWorkList){
                String accExtId = accMap.get(acc.external_Id__c).Id;
                String accName = accMap.get(acc.Id).Name;
                Decimal accRevenue = accMap.get(acc.Id).AnnualRevenue;

                if(accMap.containsKey(acc.external_Id__c) && acc.Active__c == 'Yes' && (acc.Name != accName || acc.AnnualRevenue != accRevenue) ){
                    accListToUpsert.add(
                        new Account(
                            external_Id__c = accExtId,
                            Name = accName,
                            AnnualRevenue = accRevenue
                        )
                    );
                }
            }

            if(!accListToUpsert.isEmpty()){
                upsert accListToUpsert;
            }
        }
    }

    @httpDelete
    global static void accountWorkerDelete(){
        RestRequest req = RestContext.Request;
        String reqBody = req.requestBody.toString();
        Map<String, Object> accPayload = (Map<String, Object>)JSON.deserializeUntyped(reqBody);

        Set<Id> accIds = new Set<Id>();
        for(String accId : accPayload.keySet()){
            accIds.add((Id)accId);
        }

        List<Account> accountsToDelete;
        if(!accIds.isEmpty()){
            // fetching the accounts
            accountsToDelete = new List<Account>([SELECT Id FROM Account WHERE Id IN:accountsToDelete]);
        }

        if(!accountsToDelete.isEmpty()){
            delete accountsToDelete;
        }
    }
}