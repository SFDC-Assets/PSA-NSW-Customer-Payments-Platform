@RestResource(urlMapping='/nswcpp/payment-completion')
global with sharing class NSWCPPServicePaymentCompletion {
    final static String SETTINGS_CATEGORY = 'Completion';
    final static Map<String, String> STATUS_KO_INTERNAL = 
        new Map<String, String> { 'status' => 'KO', 'message' => 'Internal Error' };
    final static Map<String, String> STATUS_KO_PERSISTENCE = 
        new Map<String, String> { 'status' => 'KO', 'message' => 'Persistence Error' };
    final static Map<String, String> STATUS_KO_AUTH = 
        new Map<String, String> { 'status' => 'KO', 'message' => 'Auth Error' };
    final static Map<String, String> STATUS_OK =
         new Map<String, String> { 'status' => 'OK' };

    class PostRequest {
        public String token;
    }

    @HttpPost
    global static Map<String, String> doPost(String token) {
        RestResponse res = RestContext.response;

        try {
            NSWCPPOperationComplete.completePayment(token);
        } catch (NSWCPPOperationComplete.NoPublicKeyException e) {
            res.statusCode = 400;
            return STATUS_KO_INTERNAL;
        } catch (NSWCPPOperationComplete.InvalidJWSException e) {
            res.statusCode = 401;
            return STATUS_KO_AUTH;
        } catch (Exception e) {
            res.statusCode = 400;
            return STATUS_KO_PERSISTENCE;
        }

        return STATUS_OK;
    }

}