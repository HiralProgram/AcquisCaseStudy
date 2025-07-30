@isTest
global class OrderProcessingControllerTest {
    
    @isTest static void testProcessWithInventoryAvailable() {
        // Setup test data
        Account acc = new Account(Name = 'Test Account', Tier__c = 'Gold');
        insert acc;
        
        Order__c order = new Order__c( Account__c = acc.Id);
        insert order;
        
        Products__c product = new Products__c(Name = 'Test Product', ProductCode__c = 'P1001',price__c=200);
        insert product;
        
        Order_Line_Item__c lineItem = new Order_Line_Item__c(
            Order__c = order.Id,
            Quantity__c = 10,
            Products__c = product.Id
        );
        insert lineItem;
        Test.setMock(HttpCalloutMock.class, new InventoryApiMock());
        Test.startTest();
        OMSQueueCallingController.processOrders(new List<Id> { order.Id });
        Test.stopTest();
        //OrderProcessingController.process(order);
       // Test.stopTest();
        
        order = [SELECT Status__c, Total_Amount__c, Discount__c, Final_Amount__c FROM Order__c WHERE Id = :order.Id];
        lineItem = [SELECT Discount__c, Final_Amount__c, Quantity_Available__c, API_Response__c FROM Order_Line_Item__c WHERE Id = :lineItem.Id];
        
        System.assertEquals('On Hold', order.Status__c, 'Order should be On Hold');
        System.assert(order.Total_Amount__c > 0, 'Total amount should be calculated');
        System.assert(lineItem.Quantity_Available__c == false, 'Quantity is not avaialble');
    }
 
    global class InventoryApiMock implements HttpCalloutMock {
        global HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            String body = '{"productId":"P1001","requestedQty":10,"availableQty":5,"isAvailable":false}';
            res.setBody(body);
            
            return res;
        }
    }
}