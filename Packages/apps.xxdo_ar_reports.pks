--
-- XXDO_AR_REPORTS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_AR_REPORTS"
IS
    --03/25/2008 - KWG - v. 1.0.1.1 -- New intl invoices columns (WO #25212) --

    --Modified the package by Vijaya Reddy @ Suneratech(offshore) on 10-MAR-2011  WO # 75555 and 77177  --

    -- Added p_from_date and  p_to_date  by Vijaya Reddy @ Suneratech(Offshore) WO # 68966  --
    PROCEDURE intl_invoices (p_d1 OUT VARCHAR2, p_d2 OUT VARCHAR2, --   p_include_style in varchar2 := 'Y',
                                                                   --p_month IN DATE := NULL,
                                                                   p_from_date IN DATE:= NULL
                             , p_to_date IN DATE:= NULL-- p_bucket_type IN NUMBER := 2,
                                                       -- v_send_none_msg IN VARCHAR2 := 'N'
                                                       );

    FUNCTION get_factory_invoice (p_cust_trx_id   IN VARCHAR2,
                                  p_style         IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE pending_edi_invoices (p_d1                 OUT VARCHAR2,
                                    p_d2                 OUT VARCHAR2,
                                    v_send_none_msg   IN     VARCHAR2 := 'N');

    PROCEDURE new_accounts (p_d1                 OUT VARCHAR2,
                            p_d2                 OUT VARCHAR2,
                            v_send_none_msg   IN     VARCHAR2 := 'N');
END;
/
