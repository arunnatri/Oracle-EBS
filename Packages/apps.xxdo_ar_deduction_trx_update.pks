--
-- XXDO_AR_DEDUCTION_TRX_UPDATE  (Package) 
--
--  Dependencies: 
--   WF_EVENT_T (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_AR_DEDUCTION_TRX_UPDATE"
IS
    FUNCTION update_transaction (p_subscription_guid   IN     RAW,
                                 p_event               IN OUT wf_event_t)
        RETURN VARCHAR2;
END XXDO_AR_DEDUCTION_TRX_UPDATE;
/
