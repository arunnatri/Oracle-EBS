--
-- XXDOINT_AR_TRX_UTILS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdoint_ar_trx_utils
    AUTHID DEFINER
AS
    PROCEDURE purge_old_batches (p_hours_old IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2);

    PROCEDURE purge_batch (p_batch_id         IN     NUMBER,
                           x_ret_stat            OUT VARCHAR2,
                           x_error_messages      OUT VARCHAR2);

    PROCEDURE process_update_batch (p_raise_event IN VARCHAR2:= 'Y', x_batch_id OUT NUMBER, x_ret_stat OUT VARCHAR2
                                    , x_error_messages OUT VARCHAR2);

    PROCEDURE process_update_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_raise_event IN VARCHAR2:= 'Y'
                                         , p_debug_level IN NUMBER:= NULL);

    PROCEDURE raise_business_event (p_batch_id IN NUMBER, x_ret_stat OUT VARCHAR2, x_error_messages OUT VARCHAR2);

    PROCEDURE reprocess_batch_conc (psqlstat OUT VARCHAR2, perrproc OUT VARCHAR2, p_hours_old IN NUMBER
                                    , p_debug_level IN NUMBER:= NULL);
END;
/


GRANT EXECUTE ON APPS.XXDOINT_AR_TRX_UTILS TO SOA_INT
/
