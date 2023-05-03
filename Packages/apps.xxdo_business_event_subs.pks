--
-- XXDO_BUSINESS_EVENT_SUBS  (Package) 
--
--  Dependencies: 
--   WF_EVENT_T (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:29 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdo_business_event_subs
IS
    /*******************************************************************************
     * Program Name : xxdo_business_event_subs
     * Language     : PL/SQL
     * Description  :
     *
     * History      :
     *
     * WHO                   WHAT              Desc                             WHEN
     * -------------- ---------------------------------------------- ---------------
     *  BT Technology team     1.0                                             17-JUN-2014
     * --------------------------------------------------------------------------- */

    FUNCTION user_subscription (
        p_subscription_quid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2;

    FUNCTION invoice_subscription (
        p_subscription_quid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2;

    FUNCTION autoinvoice_subscription (
        p_subscription_quid   IN            RAW,
        p_event               IN OUT NOCOPY wf_event_t)
        RETURN VARCHAR2;
END xxdo_business_event_subs;
/
