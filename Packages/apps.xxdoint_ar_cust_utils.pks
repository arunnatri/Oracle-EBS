--
-- XXDOINT_AR_CUST_UTILS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOINT_AR_CUST_UTILS"
    AUTHID DEFINER
AS
    PROCEDURE purge_old_batches (p_hours_old IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2);

    PROCEDURE purge_batch (p_batch_id         IN     NUMBER,
                           x_ret_stat            OUT VARCHAR2,
                           x_error_messages      OUT VARCHAR2);

    PROCEDURE process_update_batch (p_raise_event      IN     VARCHAR2 := 'Y',
                                    x_cust_batch_id       OUT NUMBER,
                                    x_site_batch_id       OUT NUMBER,
                                    x_ret_stat            OUT VARCHAR2,
                                    x_error_messages      OUT VARCHAR2);

    PROCEDURE process_relationship_batch (
        psqlstat               OUT VARCHAR2,
        perrproc               OUT VARCHAR2,
        pv_reprocess_type   IN     VARCHAR2,
        pn_batch_id         IN     NUMBER,
        pn_num_days         IN     NUMBER);

    PROCEDURE process_update_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_raise_event IN VARCHAR2:= 'Y'
                                         , p_debug_level IN NUMBER:= NULL);

    PROCEDURE raise_business_event (p_batch_id IN NUMBER, p_event_type IN VARCHAR2, x_ret_stat OUT VARCHAR2
                                    , x_error_messages OUT VARCHAR2);

    PROCEDURE reprocess_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_hours_old IN NUMBER
                                    , p_debug_level IN NUMBER:= NULL);

    FUNCTION get_site_code (p_site_use_id IN NUMBER)
        RETURN VARCHAR2;

    FUNCTION get_site_name (p_site_use_id IN NUMBER)
        RETURN VARCHAR2;

    PROCEDURE get_primary_bill_to_attrs (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_brand IN VARCHAR2:= NULL
                                         , x_site_use_id OUT NUMBER, x_code OUT VARCHAR2, x_name OUT VARCHAR2);

    FUNCTION get_primary_bill_to_id (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_brand IN VARCHAR2:= NULL)
        RETURN NUMBER;

    FUNCTION get_primary_bill_to_code (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_brand IN VARCHAR2:= NULL)
        RETURN VARCHAR2;

    FUNCTION get_primary_bill_to_name (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_brand IN VARCHAR2:= NULL)
        RETURN VARCHAR2;

    PROCEDURE get_primary_bill_to_address (p_customer_id IN NUMBER, p_org_id IN NUMBER, p_brand IN VARCHAR2:= NULL, p_bill_to_code IN VARCHAR2:= NULL, x_street1 OUT VARCHAR2, x_street2 OUT VARCHAR2, x_city OUT VARCHAR2, x_state OUT VARCHAR2, x_country OUT VARCHAR2
                                           , x_postal_code OUT VARCHAR2, x_code OUT VARCHAR2, x_name OUT VARCHAR2);

    FUNCTION get_shipping_instructions (p_customer_id   IN NUMBER,
                                        p_brand         IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION get_packing_instructions (p_customer_id   IN NUMBER,
                                       p_brand         IN VARCHAR2)
        RETURN VARCHAR2;
END;
/


GRANT EXECUTE ON APPS.XXDOINT_AR_CUST_UTILS TO SOA_INT
/

GRANT EXECUTE ON APPS.XXDOINT_AR_CUST_UTILS TO XXDO
/
