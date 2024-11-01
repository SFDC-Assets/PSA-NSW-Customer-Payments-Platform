/**
 * @description Pend a payment waiting for its completion as per sequence diagram step B.
 * @author E. Schweitzer
 */

/* TODO: Security Review by Paul Lucas
    The following would be executed by the guest user
    as a continuation of the Apex Rest service NSWCPPServicePaymentCompletion 
    The guest user cannot be granted any user access rights anyway.
    This is a narrow-band, very controlled operation.
*/

@SuppressWarnings('PMD.ApexCRUDViolation, PMD.AvoidGlobalModifier')
global without sharing class NSWCPPOperationPend {
    public class Request {
        @InvocableVariable(label='Id' required=true)
        public Id id;
        @InvocableVariable(label='Payment Reference' required=true)
        public String paymentReference;
        @InvocableVariable(label='Duplicate' required=false)
        public Boolean duplicate;
    }

    /**
      * @description Invocable method that pends a list of payments.
      * @param pendingPayment a list of Requests containing the Id, payment reference and
      *                         an indication whether the gateway sees this payment as a duplicate.
      * @return A record Id for each associated payment step or null if there was no match.
      */
    @InvocableMethod(
        category='NSW CPP' 
        label='Pend Payment' 
        description='Pends a NSW CPP Payment by Id.'
    )
    public static List<Id> pendPayment(List<Request> pendingPayment) {
        Id cpsRecordTypeId = NSWCPPOperation.getRecordTypeIdByName(NSWCPPOperation.STATUS_PENDING);
        Map<Id, Request> rqMap = new Map<Id, Request>();

        /* A payment that is flagged as a duplicate
           does not alter our course of action: if payment has been already been collected, the gateway 
           will refuse the transaction. Duplicate means that a payment was attempted but not completed. 
           Also, it should never happen as we generate a new UUID for each initiated payment. */

        for (Request item : pendingPayment) {
            rqMap.put(item.id, item);
        }

        List<NSWCPPPayment__c> cpList = [
            SELECT Id, Status__c
            FROM NSWCPPPayment__c
            WHERE Id IN :rqMap.keySet() 
                  AND Status__c = :NSWCPPOperation.STATUS_INITIATED
            FOR UPDATE
        ];

        List<NSWCPPPaymentStep__c> cpsList = new List<NSWCPPPaymentStep__c>();

        for (NSWCPPPayment__c item : cpList) {
            Request rq = rqMap.get(item.Id);

            item.PaymentReference__c = rq.paymentReference;
            item.Status__c = NSWCPPOperation.STATUS_PENDING;

            cpsList.add(
                new NSWCPPPaymentStep__c(
                    Name = item.Status__c,
                    Payment__c = item.Id,
                    RecordTypeId = cpsRecordTypeId,
                    PaymentReference__c = item.PaymentReference__c,
                    Status__c = item.Status__c,
                    Type__c = NSWCPPOperation.TYPE_PAYMENT
                )
            );
        }

        update cpList;
        insert cpsList;

        /* It's worth noting that we may not have a record for each Request at this stage, e.g.
           paymentReference is wrong or the status of it wasn't pending. We thus need
           to perform some work to stitch these records back into a meaning full result
           list. */

        Map<Id, Id> paymentStepIdByPaymentIdMap = new Map<Id, Id>();
        List<Id> rv = new List<Id>();

        for (NSWCPPPaymentStep__c cps : cpsList) {
            paymentStepIdByPaymentIdMap.put(cps.Payment__c, cps.Id);
        }

        for (Request rq : pendingPayment) {
            rv.add(paymentStepIdByPaymentIdMap.get(rq.id));
        }

        return rv;
    }

    /**
      * @description Pends a payments using a request instance
      * @param pendingPayment Request containing the Id, payment reference and
      *                         an indication whether the gateway sees this payment as a duplicate.
      * @return Record Id of the associated payment step or null if there was no match.
      */
    public static Id pendPayment(Request pendingPayment) {
        List<Id> rsList = pendPayment(new List<Request> { pendingPayment });

        return (rsList?.size() > 0) ? rsList[0] : null;
    }

    /**
      * @description Pends a payments using a direct values
      * @param id Record Id of the payment to pend.
      * @param paymentReference Payment reference issued by the payment gateway
      * @param duplicate value of the duplicate flag from the gateway
      * @return Record Id of the associated payment step or null if there was no match.
      */
    public static Id pendPayment(Id id, String paymentReference, Boolean duplicate) {
        Request rq = new Request();

        rq.id = id;
        rq.paymentReference = paymentReference;
        rq.duplicate = duplicate;
        
        return pendPayment(rq);
    }
}