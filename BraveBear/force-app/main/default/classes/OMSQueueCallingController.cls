public class OMSQueueCallingController {
@InvocableMethod(label='Process Orders Asynchronously')
    public static void processOrders(List<Id> orderIds) {
        if (!orderIds.isEmpty()) {
            System.enqueueJob(new OrderQueue(orderIds));
        }
    }
}