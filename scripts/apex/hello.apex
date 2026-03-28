List<Account> accList = [SELECT Id, Name FROM Account WHERE Name LIKE 'Test%'];

Set<Id> accId = new Set<Id>();
for(Account acc : accList){
    accId.add(acc.Id);
}
delete accList;

Set<Id> oppIds = new Set<Id>();
List<Opportunity> oppList = [SELECT AccountId FROM Opportunity WHERE AccountId IN: accList];
for(Opportunity opp : oppList){
    oppIds.add(opp.Id);
}
delete oppList;

List<OpportunityLineItem> oppLi = [SELECT OpportunityId FROM OpportunityLineItem WHERE OpportunityId IN:oppIds];
delete oppLi;