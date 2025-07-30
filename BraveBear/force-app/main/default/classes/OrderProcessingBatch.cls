global class OrderProcessingBatch implements Database.Batchable<SObject>,Database.stateful, Database.AllowsCallouts {
    
    private List<Id> orderIds;
    List<Id> OrderIdsForApprovalProcess=new List<Id>();    
    public OrderProcessingBatch(List<Id> orderIds) {
        this.orderIds = orderIds;
    }
    
    global Database.QueryLocator start(Database.BatchableContext BC) {
        return Database.getQueryLocator([
            SELECT Id, CustomerTier__c, Total_Amount__c, Discount__c, Final_Amount__c,note__c, Status__c
            FROM Order__c
            WHERE Id IN :orderIds
        ]);
    }
    
    global void execute(Database.BatchableContext BC, List<Order__c> orders) {
        // Query all Order Line Items for these orders
        Map<Id, List<Order_Line_Item__c>> orderLineItemsMap = new Map<Id, List<Order_Line_Item__c>>();
        List<Order_Line_Item__c> allLineItems = [
            SELECT Id, Quantity__c, Products__c, Products__r.ProductCode__c, Unit_Price__c,
            Discount__c, Final_Amount__c, Quantity_Available__c, API_Response__c, Order__c
            FROM Order_Line_Item__c
            WHERE Order__c IN :orderIds
        ];
        
        for (Order_Line_Item__c item : allLineItems) {
            if (!orderLineItemsMap.containsKey(item.Order__c)) {
                orderLineItemsMap.put(item.Order__c, new List<Order_Line_Item__c>());
            }
            orderLineItemsMap.get(item.Order__c).add(item);
        }
        List<Order_Line_Item__c> lineItemsToUpdate = new List<Order_Line_Item__c>();
        List<Order__c> ordersToUpdate = new List<Order__c>();
        
        for (Order__c order : orders) {
            String customerTierString = !String.isBlank(order.CustomerTier__c) ? order.CustomerTier__c : 'Standard';
            Customer_Tiers__mdt getTierMetadata = Customer_Tiers__mdt.getInstance(customerTierString);
            
            List<Order_Line_Item__c> lineItems = orderLineItemsMap.get(order.Id);
            
            Decimal total = 0;
            Decimal totalWithoutDiscount = 0;
            Boolean isInventoryQtyAvailable = true;
            
            if (lineItems != null) {
                for (Order_Line_Item__c item : lineItems) {
                    Decimal discount = getTierMetadata.Discount__c;
                    if (item.Quantity__c > 100) {
                        discount += 2;
                    }
                    Decimal price = item.Quantity__c * item.Unit_Price__c * (1 - discount / 100);
                    Decimal priceWithoutDiscount = item.Quantity__c * item.Unit_Price__c;
                    
                    item.Discount__c = discount;
                    item.Final_Amount__c = price;
                    
                    totalWithoutDiscount += priceWithoutDiscount;
                    total += price;
                    
                    try {
                        APIResponseWrapper isInventoryAvailable = checkInventoryAvailability(item.Products__r.ProductCode__c, item.Quantity__c);
                       	system.debug('isInventoryAvailable---------------------'+isInventoryAvailable);
                        item.Quantity_Available__c = isInventoryAvailable.isAvailable;
                        item.API_Response__c=isInventoryAvailable.responseBody;
                        if (!isInventoryAvailable.isAvailable) {
                            isInventoryQtyAvailable = false;
                        }
                    } catch (Exception ex) {
                        item.API_Response__c = ex.getMessage();
                        isInventoryQtyAvailable = false;
                    }
                    lineItemsToUpdate.add(item);
                }
            }
            
            order.Total_Amount__c = totalWithoutDiscount;
            order.Discount__c = !String.isBlank(order.CustomerTier__c) ? getTierMetadata.Discount__c : 0.0;
            order.Final_Amount__c = total; // final amount after discounts
            
            if (isInventoryQtyAvailable) {
                if (total > getTierMetadata.Auto_Approval_Limit__c) {
                    order.Status__c = 'Manager Approval';
                    order.Note__c='Waiting for managers approval';
                    OrderIdsForApprovalProcess.add(order.Id);                    
                } 
                else {
                    order.Status__c = 'Approved';
                }
            }
            else {
                order.Status__c = 'On Hold';
                order.note__c='Inventory is not available';
            }
            
            ordersToUpdate.add(order);
        }
        
        if (!lineItemsToUpdate.isEmpty()) {
            update lineItemsToUpdate;
        }
        
        if (!ordersToUpdate.isEmpty()) {
            update ordersToUpdate;
        }
    }
    
    global void finish(Database.BatchableContext BC) {
        if (!OrderIdsForApprovalProcess.isEmpty()) {
            List<Order__c> orderToSubmitForApproval = [ SELECT Id FROM Order__c WHERE Id IN :OrderIdsForApprovalProcess    AND Status__c = 'Manager Approval'];
            
            for (Order__c order : orderToSubmitForApproval) {
                try {
                    Approval.ProcessSubmitRequest req = new Approval.ProcessSubmitRequest();
                    req.setObjectId(order.Id);
                    Approval.process(req);
                } catch (Exception ex) {
                    System.debug('Error approving order ' + order.Id + ': ' + ex.getMessage());
                }
            }
        }
        
    }
    
    public static APIResponseWrapper checkInventoryAvailability(String productId, decimal quantity) {
     /*   HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:ExternalInventoryAPI/inventory/check?productId=' + productId + '&qty=' + quantity);
        req.setMethod('GET');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        APIResponseWrapper wrp=new APIResponseWrapper();
        wrp.responseBody=res.getBody();
        if (res.getStatusCode() == 200) {
            Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            if (response.containsKey('isAvailable')) {
                wrp.isAvailable=true;
                
                //wrp.isAvailable=(Boolean)response.get('isAvailable');
                return wrp;
            }
        }
        else {
            //wrp.isAvailable=false;
            wrp.isAvailable=true;
        }*/
		APIResponseWrapper wrp=new APIResponseWrapper();  
        wrp.isAvailable=true;
        wrp.responseBody='{"productId":"P1001","requestedQty":10,"availableQty":5,"isAvailable":false}';
        return wrp;
    }
    public class APIResponseWrapper {
        public Boolean isAvailable;
        public String responseBody;
    }
}