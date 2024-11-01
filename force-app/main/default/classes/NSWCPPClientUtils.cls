global with sharing class NSWCPPClientUtils implements Callable {
    global Object call(String action, Map<String, Object> args) {
        Map<String, Object> input = (Map<String, Object>) args.get('input');
        Map<String, Object> output = (Map<String, Object>) args.get('output');
        Map<String, Object> options = (Map<String, Object>) args.get('options');

        switch on action {
            when 'getUUID' {
                String prefix = String.valueOf(input.get('prefix'));
                output.put('result', NSWCPPClientUtilsGetUUID.getUUID(prefix));
                return true;
            }
            when 'initiatePayment' {
                if (input.isEmpty()) {
                    setError(output, 'ARGLIST-002');
                    return false;
                }

                NSWCPPOperationInitiate.Request rq = new NSWCPPOperationInitiate.Request();
                rq.agencyTransactionId = String.valueOf(input.get('agencyTransactionId'));
                rq.amount = (Decimal) input.get('amount');
                rq.productDescription = String.valueOf(input.get('productDescription'));
                rq.customerReference = String.valueOf(input.get('customerReference'));

                Id rv = NSWCPPOperationInitiate.initiatePayment(rq);

                output.put('result', new Map<String, Object> { 'id' => rv });
                return true;
            }
            when 'pendPayment' {
                if (input.isEmpty()) {
                    setError(output, 'ARGLIST-002');
                    return false;
                }

                NSWCPPOperationPend.Request rq = new NSWCPPOperationPend.Request();
                rq.id = String.valueOf(input.get('id'));
                rq.paymentReference = String.valueOf(input.get('paymentReference'));
                rq.duplicate = Boolean.valueOf(input.get('duplicate'));

                NSWCPPOperationPend.pendPayment(rq);

                output.put('result', true);
                return true;
            }
            when 'requestPayment' {
                if (input.isEmpty()) {
                    setError(output, 'ARGLIST-002');
                    return false;
                }

                output.put('result', NSWCPPCalloutRequestPayment.requestPayment(input));
                return true;
            }
            when 'closePayment' {
                if (input.isEmpty()) {
                    setError(output, 'ARGLIST-002');
                    return false;
                }

                NSWCPPOperationClose.Request rq = new NSWCPPOperationClose.Request();
                rq.paymentReference = String.valueOf(input.get('paymentReference'));

                NSWCPPOperationClose.closePayment(rq);

                output.put('result', true);
                return true;
            }
            when else {
                return setError(output, 'ACTION-001');
            }
        }
    }

    public Boolean setError(Map<String, Object> output, String errorCode) {
        output.put('error', 'KO');
        output.put('errorCode', errorCode);
        return false;
    }
}