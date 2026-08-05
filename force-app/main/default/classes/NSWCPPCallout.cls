/**
 * @description Base class for all NSW CPP HTTP callout classes. Handles constructor-time
 *              initialisation: resolves the current network context to a NSWCPPCallingSystem__mdt
 *              record, loads named credentials and the payment URL, and applies optional callout
 *              settings (timeout, compression) from NSWCPPSetting__mdt.
 *              Subclasses inherit the protected callout() and mergeParams() methods to execute
 *              HTTP requests against the NSW CPP gateway.
 * @author E. Schweitzer
 * @see NSWCPPCalloutRequestPayment
 * @see NSWCPPCalloutGetPaymentStatus
 * @see NSWCPPCalloutRefundPayment
 */
public virtual class NSWCPPCallout {
    /** @description Network name used when no Experience Cloud network is active (internal app context). */
    public final static String APP_NETWORK = '__SALESFORCEAPP';

    /** @description Default HTTP callout timeout in milliseconds. */
    final static Integer DEFAULT_CALLOUT_TIMEOUT = 5000;
    /** @description Default HTTP callout compression flag. */
    final static Boolean DEFAULT_CALLOUT_COMPRESSED = false;
    /** @description NSWCPPSetting__mdt category used to load callout settings. */
    final static String SETTING_CATEGORY_CALLOUT = 'Callout';

    /** @description Effective callout timeout, overridable via NSWCPPSetting__mdt. */
    Integer calloutTimeout = DEFAULT_CALLOUT_TIMEOUT;
    /** @description Effective callout compression flag, overridable via NSWCPPSetting__mdt. */
    Boolean calloutCompressed = DEFAULT_CALLOUT_COMPRESSED;
    /** @description Named credential API name resolved from the matched NSWCPPCallingSystem__mdt record. */
    String namedCredentials;
    /** @description Label of the resolved calling system, injected into outbound request payloads. */
    protected String callingSystem;
    /** @description Payment redirect URL template resolved from the matched NSWCPPCallingSystem__mdt record. */
    protected String paymentURL;

    /**
     * @description Thrown by the NSWCPPCallout constructor when no NSWCPPCallingSystem__mdt
     *              record can be matched to the current network context. This typically means
     *              the custom metadata has not been configured for the Experience Cloud site or
     *              internal app from which the callout is being made.
     * @see NSWCPPCallout.getCallingSystem
     */
    public class NSWCPPNoCallingSystemException extends Exception {}

    /**
     * @description Initialises the callout by resolving the calling system for the current
     *              network context and loading callout settings from custom metadata.
     * @throws NSWCPPNoCallingSystemException when no NSWCPPCallingSystem__mdt record matches
     *                                        the current network.
     */
    protected NSWCPPCallout() {
        List<NSWCPPCallingSystem__mdt> csList = getCallingSystem();

        if (csList == null || csList.size() == 0) {
            throw new NSWCPPNoCallingSystemException('No calling system found.');
        }

        this.callingSystem = csList.get(0).Label;
        this.namedCredentials = csList.get(0).NamedCredentials__c;
        this.paymentURL = csList.get(0).PaymentURL__c;

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

    /**
     * @description Resolves the NSWCPPCallingSystem__mdt record for the current execution context.
     *              Attempts to determine the active Experience Cloud network name via Network.getNetworkId().
     *              Falls back to APP_NETWORK when running outside an Experience Cloud site.
     * @return A list containing the matched NSWCPPCallingSystem__mdt record, an empty list if no
     *         match was found, or null if an exception occurred during resolution.
     */
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

    /**
     * @description Executes an HTTP request against the NSW CPP gateway using the named credential
     *              resolved at construction time. The payload is serialised to JSON with null values
     *              suppressed. Subclasses may override this method to substitute a mock response
     *              during testing.
     * @param url Relative URL path to append to the named credential endpoint (e.g. /api/request-payment).
     * @param method HTTP verb (GET, POST, etc.).
     * @param payload Object to serialise as the request body. Pass null for requests with no body.
     * @return The raw HttpResponse from the gateway.
     */
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

    /**
     * @description Substitutes named placeholders in a URL template with URL-encoded parameter values.
     *              Placeholders must be wrapped in curly braces (e.g. {paymentReference}).
     *              Each value is URL-encoded using UTF-8 to prevent path injection.
     * @param url URL template string containing one or more {key} placeholders.
     * @param params Map of placeholder names to their replacement values.
     * @return The URL with all matching placeholders replaced by their encoded values.
     */
    @TestVisible
    protected String mergeParams(String url, Map<String, String> params) {
        for (String key: params.keySet()) {
            // URL encode key
            url = url.replace('{' + key + '}', EncodingUtil.urlEncode(params.get(key), 'UTF-8'));
        }

        return url;
    }
}