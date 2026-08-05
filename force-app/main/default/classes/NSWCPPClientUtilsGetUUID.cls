/**
 * @description Utility class that generates universally unique identifiers (UUIDs) for use as
 *              agency transaction IDs and other unique reference values in the NSW CPP platform.
 *              Exposes both an @InvocableMethod entry point for Flow/OmniScript use and
 *              lightweight static helpers for direct Apex invocation.
 * @author E. Schweitzer
 */
public class NSWCPPClientUtilsGetUUID {

    /**
     * @description Input wrapper for the @InvocableMethod. Carries an optional prefix
     *              string to prepend to the generated UUID.
     */
    public class Request {
        @InvocableVariable(label='Prefix' required=false)
        public String prefix;
    }

    /**
     * @description Invocable entry point for Flow and OmniScript consumers.
     *              Generates one UUID per Request element, optionally prepending
     *              the supplied prefix to each result.
     * @param requests List of Request objects, each carrying an optional prefix.
     * @return A list of UUID strings in the same order as the input list.
     */
    @InvocableMethod(
        category='NSW CPP Client'
        label='Get UUID'
        description='Get a unique transaction ID.'
    )
    public static List<String> getUUID(List<Request> requests) {
        List<String> rv = new List<String>();

        for (Request singlePrefix : requests) {
            rv.add(getUUID(singlePrefix.prefix));
        }

        return rv;
    }

    /**
     * @description Generates a UUID with no prefix.
     * @return A UUID string in the format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.
     */
    public static String getUUID() {
        return getUUID('');
    }

    /**
     * @description Generates a UUID optionally prepended with the given prefix.
     *              A null prefix is treated as an empty string.
     * @param prefix String to prepend to the UUID, or null for no prefix.
     * @return The prefix (if any) concatenated with a UUID string.
     */
    public static String getUUID(String prefix) {
        return (prefix == null ? '' : prefix) + UUID.randomUUID().toString();
    }
}