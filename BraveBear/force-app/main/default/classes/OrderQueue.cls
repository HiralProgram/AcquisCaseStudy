public class OrderQueue implements Queueable, Database.AllowsCallouts {
    private List<Id> orderIds;
    
    public OrderQueue(List<Id> orderIds) {
        this.orderIds = orderIds;
    }
    
    public void execute(QueueableContext context) {
        List<Order__c> orders = [SELECT Id,Account__c,Total_Amount__c,Discount__c,Final_Amount__c,status__c FROM Order__c WHERE Id IN :orderIds];
        
        for (Order__c order : orders) {
            OrderProcessingController.process(order);
        }
    }
}