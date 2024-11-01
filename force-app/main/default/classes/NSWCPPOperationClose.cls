/**
 * @description Close a payment that failed and persist a step.
 * @author E. Schweitzer
 */

/* TODO: Security Review by Paul Lucas
    The following would be executed by the guest user
    as a continuation of the Apex Rest service NSWCPPServicePaymentCompletion 
    The guest user cannot be granted any user access rights anyway.
    This is a narrow-band, very controlled operation.
*/

@SuppressWarnings('PMD.ApexCRUDViolation, PMD.AvoidGlobalModifier')
global without sharing class NSWCPPOperationClose {
    public class Request {
        @InvocableVariable(label='Payment Reference' required=true)
        public String paymentReference;
    }

    /**
      * @description Invocable method that closes failed NSW CPP payments by payment reference
      *              and returns a list of the associated payment step recordId (or null if there 
      *              was no match)
      * @param pendingPayment a list of Requests containing payment references
      * @return a list of NSWCPPPaymentStep__c Ids or null if there was not payment reference match
      * @see NSWCPPOperationClose.Request
      * @see NSWCPPOperationClose.Result
      */
    @InvocableMethod(
        category='NSW CPP' 
        label='Close Payment' 
        description='Closes a failed NSW CPP Payment by Payment Reference.'
    )
    public static List<Id> closePayment(List<Request> pendingPayment) {
        final Id cpsRecordTypeId = NSWCPPOperation.getRecordTypeIdByName(NSWCPPOperation.STATUS_FAILED);
        Set<String> prSet = new Set<String>();

        for (Request rq : pendingPayment) {
            prSet.add(rq.paymentReference);
        }

        List<NSWCPPPayment__c> cpList = [
            SELECT Id, Status__c, PaymentReference__c
            FROM NSWCPPPayment__c
            WHERE PaymentReference__c IN :prSet 
                AND Status__c = :NSWCPPOperation.STATUS_PENDING
            FOR UPDATE
        ];

        List<NSWCPPPaymentStep__c> cpsList = new List<NSWCPPPaymentStep__c>();
        for (NSWCPPPayment__c item : cpList) {
            item.Status__c = NSWCPPOperation.STATUS_FAILED;

            cpsList.add(
                new NSWCPPPaymentStep__c(
                    Name = item.Status__c,
                    Payment__c = item.Id,
                    PaymentReference__c = item.PaymentReference__c,
                    RecordTypeId = cpsRecordTypeId,
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

        Map<String, Id> paymentStepIdByPaymentReferenceMap = new Map<String, Id>();
        List<Id> rv = new List<Id>();

        for (NSWCPPPaymentStep__c cps : cpsList) {
            paymentStepIdByPaymentReferenceMap.put(cps.PaymentReference__c, cps.Id);
        }

        for (Request rq : pendingPayment) {
            rv.add(paymentStepIdByPaymentReferenceMap.get(rq.paymentReference));
        }

        return rv;
    }

    /**
      * @description Closes a failed NSW CPP payment by payment reference
      *              and returns the associated payment step recordId (or null if there was no match)
      * @param pendingPayment a Request containing the payment reference
      * @see NSWCPPOperationClose.Request
      * @return The NSWCPPPaymentStep__c Id or null if there was not payment reference match
      */
    public static Id closePayment(Request pendingPayment) {
        final List<Id> rv = closePayment(new List<Request> { pendingPayment });
        
        return rv?.size() > 0 ? rv[0] : null;
    }

    /**
      * @description Closes a failed NSW CPP payment by payment reference
      *              and returns the associated payment step recordId (or null if there was no match)
      * @param pendingPaymentReference The target payment reference
      * @return The NSWCPPPaymentStep__c Id or null if there was not payment reference match
      */
    public static Id closePayment(String paymentReference) {
        Request pendingPayment = new Request();

        pendingPayment.paymentReference = paymentReference;

        final List<Id> rv = closePayment(new List<Request> { pendingPayment });
        
        return rv?.size() > 0 ? rv[0] : null;
    }
}