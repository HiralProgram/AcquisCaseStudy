public class OMSQueueCallingController {
@InvocableMethod(label='Process Orders Asynchronously')
    public static void processOrders(List<Id> orderIds) {
        if (!orderIds.isEmpty()) {
               
        Database.executeBatch(new OrderProcessingBatch(orderIds), 10);
            //System.enqueueJob(new OrderQueue(orderIds));
        }
    }
}