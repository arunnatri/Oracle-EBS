--
-- XXDOINV_CONSOL_INV_EXTRACT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:46 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOINV_CONSOL_INV_EXTRACT_PKG"
/***************************************************************************************
  *                                                                                    *
  * History                                                                            *
  * Vsn     Change Date      Changed By            Change Description                  *
  * -----   -----------     ------------------     ------------------------------------*
  * 1.0     13-JUN-2014     BT Technology team     Base Version                        *
  * 2.1     29-NOV-2017     Arun N Murthy          EU First Sale Project CCR0006823    *
  * 3.0     05-AUG-2020     Srinath Siricilla      CCR0008682                          *
  * 3.1     03-APR-2021     Showkath Ali           AAR Project
  **************************************************************************************/
IS
    --Start Changes by V2.1
    FUNCTION get_max_seq_value (pn_inventory_item_id NUMBER, pn_organization_id NUMBER, p_as_of_date DATE)
        RETURN NUMBER;

    --End Changes by V2.1
    PROCEDURE run_cir_report (
        psqlstat                      OUT VARCHAR2,
        perrproc                      OUT VARCHAR2,
        p_retrieve_from            IN     VARCHAR2, -- Added as per CCR0008682
        p_inv_org_id               IN     NUMBER,
        p_region                   IN     VARCHAR2,
        p_as_of_date               IN     VARCHAR2,
        p_brand                    IN     VARCHAR2,
        p_master_inv_org_id        IN     NUMBER,
        p_xfer_price_list_id       IN     NUMBER,
        p_duty_override            IN     NUMBER := 0,
        p_summary                  IN     VARCHAR2,
        p_include_analysis         IN     VARCHAR2,
        p_use_accrual_vals         IN     VARCHAR2 := 'Y',
        p_from_Currency            IN     VARCHAR2,
        p_elimination_rate_type    IN     VARCHAR2,
        p_elimination_rate         IN     VARCHAR2,
        p_dummy_elimination_rate   IN     VARCHAR2,
        p_user_rate                IN     NUMBER,
        p_TQ_Japan                 IN     VARCHAR2,
        p_dummy_tq                 IN     VARCHAR2,
        p_markup_rate_type         IN     VARCHAR2,
        --p_dummy_markup_rate    IN       VARCHAR2,
        p_jpy_user_rate            IN     NUMBER,
        p_debug_level              IN     NUMBER := NULL,
        p_layered_mrgn             IN     VARCHAR2,
        p_report_type              IN     VARCHAR2,                     -- 3.1
        p_file_path                IN     VARCHAR2                       --3.1
                                                  );
END;
/
