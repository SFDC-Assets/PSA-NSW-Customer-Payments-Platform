@isTest
private class NSWCPPOperationClose_Test {

    static String refForNumber(String stub, Integer i) {
        return stub + '_' + String.valueOf(i);
    }

    @isTest
    static void mustCloseLegitimateOperationCorrectly() {
        final String stub = 'MyUniquePaymentReference_' + System.now().getTime();
        final Integer numberRecords = 5;
        final Integer referenceRecordIndex = 0;

        /* Prepare records */
        /* --------------- */

        Test.startTest();

        List<NSWCPPPayment__c> oldPaymentList = new List<NSWCPPPayment__c>();

        for (Integer i = 0; i < numberRecords; i++) {
            oldPaymentList.add(new NSWCPPPayment__c(
                Status__c = NSWCPPOperation.STATUS_PENDING,
                PaymentReference__c = refForNumber(stub, i)
            ));
        }

        insert oldPaymentList;

        NSWCPPOperationClose.Request rq = new NSWCPPOperationClose.Request();
        List<NSWCPPOperationClose.Request> rqList = new List<NSWCPPOperationClose.Request> { rq };

        rq.paymentReference = refForNumber(stub, referenceRecordIndex);
        List<Id> rsList = NSWCPPOperationClose.closePayment(rqList);

        Test.stopTest();

        /* Perform tests */
        /* ------------- */

        Map<Id, NSWCPPPayment__c> oldPaymentMap = new Map<Id, NSWCPPPayment__c>(oldPaymentList);

        Map<Id, NSWCPPPayment__c> newPaymentMap = new Map<Id, NSWCPPPayment__c>([
            SELECT Id, Status__c, PaymentReference__c
            FROM NSWCPPPayment__c
            WHERE Id IN :oldPaymentMap.keySet()
        ]);

        System.assertEquals(
            numberRecords, 
            newPaymentMap.size(), 
            'All payment records should be accounted for');

        Id referenceRecordId = oldPaymentList[referenceRecordIndex].Id;

        for (Id newPaymentId : newPaymentMap.keySet()) {
            NSWCPPPayment__c newPayment = newPaymentMap.get(newPaymentId);

            if (newPaymentId != referenceRecordId) {
                System.assertEquals(
                    NSWCPPOperation.STATUS_PENDING, 
                    newPayment.Status__c, 
                    'All other payments should still be pending');
            } else {
                System.assertEquals(
                    NSWCPPOperation.STATUS_FAILED, 
                    newPayment.Status__c, 
                    'Reference payment should be failed');
            }
        }

        /* Now check steps */

        List<NSWCPPPaymentStep__c> paymentStepList = [
            SELECT Id, Payment__c, PaymentReference__c, Status__c
            FROM NSWCPPPaymentStep__c
            WHERE Payment__c IN :oldPaymentMap.keySet()
        ];

        Map<Id, List<NSWCPPPaymentStep__c>> paymentStepListMapByPaymentId = new Map<Id, List<NSWCPPPaymentStep__c>>();

        for (NSWCPPPaymentStep__c step : paymentStepList) {
            List<NSWCPPPaymentStep__c> paymentStepListForPayment = paymentStepListMapByPaymentId.get(step.id);
            
            if (paymentStepListForPayment == null) {
                paymentStepListForPayment = new List<NSWCPPPaymentStep__c>();

                paymentStepListMapByPaymentId.put(step.Payment__c, paymentStepListForPayment);
            }

            paymentStepListForPayment.add(step);
        }

        for (Id newPaymentId : newPaymentMap.keySet()) {
            List<NSWCPPPaymentStep__c> paymentStepListForPayment =  paymentStepListMapByPaymentId.get(newPaymentId);

            Integer size = paymentStepListForPayment != null ? paymentStepListForPayment.size() : 0;

            if (newPaymentId != referenceRecordId) {
                System.assertEquals(
                    0, 
                    size, 
                    'All other payments should not have added steps');
            } else {
                System.assertEquals(
                    1, 
                    size, 
                    'Reference payment should have a single step');
            }
        }
    }

    @isTest
    static void mustReturnNullWhenPaymentReferenceIsUnknown() {
        final String paymentReference = 'MyUniquePaymentReference_' + System.now().getTime();

        Test.startTest();
        Id nullId = NSWCPPOperationClose.closePayment(paymentReference);
        Test.stopTest();

        System.assertEquals(
            null, 
            nullId, 
            'Closing unknown reference should return null id');
    }

    @isTest
    static void mustReturnNullWhenPaymentReferenceIsNotPending() {
        final String paymentReference = 'MyUniquePaymentReference_' + System.now().getTime();

        Test.startTest();
        insert new NSWCPPPayment__c(
            Status__c = NSWCPPOperation.STATUS_COMPLETED,
            PaymentReference__c = paymentReference
        );

        NSWCPPOperationClose.Request rq = new NSWCPPOperationClose.Request();
        rq.paymentReference = paymentReference;

        Id nullId = NSWCPPOperationClose.closePayment(paymentReference);
        Test.stopTest();

        System.assertEquals(
            null, 
            nullId, 
            'Closing reference that is not pending should return null id');
    }
}