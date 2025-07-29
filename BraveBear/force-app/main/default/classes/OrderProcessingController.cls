public class OrderProcessingController {
    public static void process(Order__c order) {
        Account acc = [SELECT Tier__c FROM Account WHERE Id = :order.Account__c];
        Customer_Tiers__mdt	 getTierMetadata;
        String customerTierString= !string.isBlank(acc.Tier__c) ? acc.tier__c: 'Standard';
        boolean isInventoryQtyAvailable=true;
        
        getTierMetadata = Customer_Tiers__mdt.getInstance(customerTierString);        
        List<Order_Line_Item__c> lineItems = [SELECT Quantity__c,Products__c,products__r.ProductCode__c	,unit_price__c FROM Order_Line_Item__c WHERE Order__c = :order.Id];//
        Decimal total = 0;
        Decimal totalWithoutDiscount = 0;
        for (Order_Line_Item__c item : lineItems) {
            Decimal discount =   getTierMetadata.Discount__c;
            if (item.Quantity__c > 100) {
                discount += 2;
            }
            Decimal price = item.Quantity__c * item.unit_price__c * (1 - discount / 100);
            Decimal PriceWithoutDiscount=item.Quantity__c * item.unit_price__c;
            item.Discount__c = discount;
            item.Final_Amount__c = price;
            totalWithoutDiscount+=PriceWithoutDiscount;
            total += price;
            system.debug('Total Amount '+total);
            try {
                //  Boolean isInventoryAvailable = true;
                Boolean isInventoryAvailable = checkInventoryAvailability(item.products__r.ProductCode__c, item.Quantity__c);
                item.Quantity_Available__c=isInventoryAvailable;
                
                if (!isInventoryAvailable) {
                    isInventoryQtyAvailable = false;
                }
            } catch (Exception ex) {
                item.API_Response__c=ex.getMessage();
                isInventoryQtyAvailable = false;
                System.debug('Inventory API call failed: ' + ex.getMessage());
            }
        }
        update lineItems;
        
        order.Total_Amount__c = total;
        order.Discount__c =   !string.isBlank(acc.Tier__c) ? getTierMetadata.Discount__c: 0.0;
        order.Final_Amount__c = totalWithoutDiscount;
        if(isInventoryQtyAvailable){
            if (total > getTierMetadata.Auto_Approval_Limit__c) {
                order.Status__c = 'Manager Approval';
            } else {
                order.Status__c = 'Approved';
            }
        }
        else order.Status__c='On Hold';
        update order;
    }
    
    public static Boolean checkInventoryAvailability(String productId, Decimal quantity) {
        HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:ExternalInventoryAPI/inventory/check?productId=' + productId + '&qty=' + quantity);
    req.setMethod('GET');

    Http http = new Http();
    HttpResponse res = http.send(req);

    if (res.getStatusCode() == 200) {
        // Parse the JSON response
        Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        if (response.containsKey('isAvailable')) {
            return (Boolean) response.get('isAvailable');
        }
    }
    return false;
    }
}