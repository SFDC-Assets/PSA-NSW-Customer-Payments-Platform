public with sharing virtual class NSWCPPCallout {
    public final static String APP_NETWORK = '__SALESFORCEAPP';

    final static Integer DEFAULT_CALLOUT_TIMEOUT = 5000;
    final static Boolean DEFAULT_CALLOUT_COMPRESSED = false;
    final static String SETTING_CATEGORY_CALLOUT = 'Callout';

    Integer calloutTimeout = DEFAULT_CALLOUT_TIMEOUT;
    Boolean calloutCompressed = DEFAULT_CALLOUT_COMPRESSED;
    String namedCredentials;
    protected String callingSystem;
    protected String paymentURL;

    public class NSWCPPNoCallingSystemException extends Exception {}

    protected NSWCPPCallout() {
        List<NSWCPPCallingSystem__mdt> csList = getCallingSystem();

        if (csList == null || csList.size() == 0) {
            throw new NSWCPPNoCallingSystemException('No calling system found.');
        }

        this.callingSystem = csList.get(0).Label;
        this.namedCredentials = csList.get(0).NamedCredentials__c;
        this.paymentUrl = csList.get(0).PaymentURL__c;

        Map<String, String> settings = NSWCPPSettings.getSettingsMapForCategory(SETTING_CATEGORY_CALLOUT);

        for (String settingKey : settings.keySet()) {
            String setting = settings.get(settingKey);
            switch on settingKey {
                when 'timeout' {
                    this.calloutTimeout = Integer.valueOf(setting);
                }
                when 'compressed' {
                    this.calloutCompressed = Boolean.valueOf(setting);
                }
            }
        }
    }

    protected List<NSWCPPCallingSystem__mdt> getCallingSystem() {
        try {
            String networkName = APP_NETWORK;
            Id networkId = Network.getNetworkId();

            if (networkId != null) {
                List<Network> networks = [
                    SELECT Id, Name 
                    FROM Network 
                    WHERE Id = :networkId
                    WITH USER_MODE
                    LIMIT 1
                ];

                if (networks.size() > 0) {
                    networkName = networks[0].Name;
                }
            }

            return [
                SELECT Label, Network__c, NamedCredentials__c, PaymentURL__c
                FROM NSWCPPCallingSystem__mdt
                WHERE Network__c = :networkName
                WITH USER_MODE
                LIMIT 1
            ];
        } catch (Exception e) {
            return null;
        }
    }

    protected virtual HttpResponse callout(String url, String method, Object payload) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:' + this.namedCredentials + url);
        req.setMethod(method);
        req.setTimeout(this.calloutTimeout);
        req.setCompressed(this.calloutCompressed);
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(payload, true));

        System.debug('callout ' + JSON.serialize(payload, true));
        Http http = new Http();
        return http.send(req);
    }

    protected String mergeParams(String url, Map<String, String> params) {
        for (String key: params.keySet()) {
            url = url.replace('{' + key + '}', params.get(key));
        }

        return url;
    }
}