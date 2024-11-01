/**
 * @description Refund a payment (totally or partially).
 * @author E. Schweitzer
 */

/* TODO: Security Review by Paul Lucas
    The following would be executed by the guest user
    as a continuation of the Apex Rest service NSWCPPServicePaymentCompletion 
    The guest user cannot be granted any user access rights anyway.
    This is a narrow-band, very controlled operation.
*/

@SuppressWarnings('PMD.ApexCRUDViolation, PMD.AvoidGlobalModifier')
global without sharing class NSWCPPOperationRefund {
    public class Request {
        @InvocableVariable(label='Id' required=true)
        public Id id;
        @InvocableVariable(label='Amount' required=true)
        public Decimal amount;
        @InvocableVariable(label='Refund Reason' required=true)
        public String refundReason;
        @InvocableVariable(label='Refund Reference' required=true)
        public String refundReference;
        @InvocableVariable(label='Duplicate' required=false)
        public Boolean duplicate;
        @InvocableVariable(label='Failure Reason' required=false)
        public String failureReason;
    }

    /**
      * @description Invocable method that performs a list of refunds.
      * @param refund a list of Requests containing the Id of the completed payment, refund reference and
      *                         an indication whether the gateway sees this refund as a duplicate.
      *                 Failure reason if it's not been successful, leave empty if success.
      * @return A record Id for each associated payment step or null if there was no match.
      */
    @InvocableMethod(
        category='NSW CPP' 
        label='Refund Payment' 
        description='Refunds a NSW CPP Payment by Id.'
    )
    public static List<Id> refundPayment(List<Request> refund) {
        Id cpsRecordTypeId = NSWCPPOperation.getRecordTypeIdByName(NSWCPPOperation.TYPE_REFUND);
        Map<Id, Request> rqMap = new Map<Id, Request>();

        /* A payment that is flagged as a duplicate
           does alter our course of action: if refund has been already been collected, we do not persist. */

        for (Request item : refund) {
            rqMap.put(item.id, item);
        }

        List<NSWCPPPayment__c> cpList = [
            SELECT Id, Status__c
            FROM NSWCPPPayment__c
            WHERE Id IN :rqMap.keySet() 
                  AND Status__c = :NSWCPPOperation.STATUS_COMPLETED
            FOR UPDATE
        ];

        List<NSWCPPPaymentStep__c> cpsList = new List<NSWCPPPaymentStep__c>();

        for (NSWCPPPayment__c item : cpList) {
            Request rq = rqMap.get(item.Id);

            cpsList.add(
                new NSWCPPPaymentStep__c(
                    Name = 'Refund',
                    Payment__c = item.Id,
                    RecordTypeId = cpsRecordTypeId,
                    RefundReference__c = rq.refundReference,
                    Status__c = String.isBlank(rq.failureReason) ? NSWCPPOperation.STATUS_COMPLETED : NSWCPPOperation.STATUS_FAILED,
                    Type__c = NSWCPPOperation.TYPE_REFUND
                )
            );
        }

        insert cpsList;

        Map<Id, Id> paymentStepIdByPaymentIdMap = new Map<Id, Id>();
        List<Id> rv = new List<Id>();

        for (NSWCPPPaymentStep__c cps : cpsList) {
            paymentStepIdByPaymentIdMap.put(cps.Payment__c, cps.Id);
        }

        for (Request rq : refund) {
            rv.add(paymentStepIdByPaymentIdMap.get(rq.id));
        }

        return rv;
    }

    /**
      * @description Refunds a payment using a request instance
      * @param refund a list of Requests containing the Id of the completed payment, refund reference and
      *                         an indication whether the gateway sees this refund as a duplicate.
      *                 Failure reason if it's not been successful, leave empty if success.
      * @return Record Id of the associated payment step or null if there was no match.
      */
    public static Id refundPayment(Request refund) {
        List<Id> rsList = refundPayment(new List<Request> { refund });

        return (rsList?.size() > 0) ? rsList[0] : null;
    }

    /**
      * @description Refunds a payment using a direct values
      * @param id Record Id of the completed payment to refund.
      * @param refundReference Refund reference issued by the payment gateway
      * @param duplicate value of the duplicate flag from the gateway
      * @param failureReason reason why the payment failed, or null when successful
      * @return Record Id of the associated payment step or null if there was no match.
      */
    public static Id refundPayment(Id id, String amount, String refundReason, String refundReference, Boolean duplicate, String failureReason) {
        Request rq = new Request();

        rq.id = id;
        rq.amount = amount;
        rq.refundReason = refundReason;
        rq.refundReference = refundReference;
        rq.duplicate = duplicate;
        rq.failureReason = failureReason;
        
        return refundPayment(rq);
    }
}