--
-- XXDO_INT_WMS_UTIL  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_INT_WMS_UTIL"
AS
    FUNCTION get_wms_timezone (p_site_id IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_offset (p_timezone IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_first_of_next_month (p_date IN DATE:= SYSDATE)
        RETURN DATE;

    PROCEDURE process_txn_date_records (errbuf    OUT VARCHAR2,
                                        retcode   OUT VARCHAR2);

    FUNCTION get_wms_org_id (p_site_id VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_wms_org_code (p_site_id VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_file_adjusted_time (p_shipment_date IN DATE, p_site_id IN VARCHAR2, p_svr_date IN DATE:= SYSDATE)
        RETURN DATE;
END XXDO_INT_WMS_UTIL;
/


GRANT EXECUTE ON APPS.XXDO_INT_WMS_UTIL TO XXDO
/
