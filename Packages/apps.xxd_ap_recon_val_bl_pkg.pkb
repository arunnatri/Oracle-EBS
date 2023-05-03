--
-- XXD_AP_RECON_VAL_BL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_RECON_VAL_BL_PKG"
AS
    /****************************************************************************************
       * Package      : XXD_AP_PAY_RECON_BL_PKG
       * Design       : This package is used for update value set XXD_AP_PAY_RECON_HIST_ID_VS after concurrent program
                        'Deckers AP Payments To Blackline' is completed sucessfully
       * Notes        :
       * Modification :
       -- ===============================================================================
       -- Date         Version#   Name                    Comments
       -- ===============================================================================
       -- 12-OCT-2020  1.0      Tejaswi Gangumala      Initial Version
       ******************************************************************************************/
    PROCEDURE update_value_set (pv_errbuf OUT VARCHAR2, pv_retcode OUT NUMBER, pv_module IN VARCHAR2
                                , pn_request_id IN NUMBER, pn_organization_id NUMBER, pn_max_id IN NUMBER)
    AS
        v_complete      BOOLEAN;
        lv_phase        VARCHAR2 (200);
        lv_status       VARCHAR2 (200);
        lv_dev_phase    VARCHAR2 (200);
        lv_dev_status   VARCHAR2 (200);
        lv_message      VARCHAR2 (200);
    BEGIN
        IF pv_module = 'AP'
        THEN
            v_complete   :=
                fnd_concurrent.wait_for_request (
                    request_id   => pn_request_id,
                    INTERVAL     => 15,
                    max_wait     => 180,
                    phase        => lv_phase,
                    status       => lv_status,
                    dev_phase    => lv_dev_phase,
                    dev_status   => lv_dev_status,
                    MESSAGE      => lv_message);

            IF lv_phase = 'Completed' AND lv_status = 'Normal'
            THEN
                BEGIN
                    UPDATE apps.fnd_flex_values_vl flv
                       SET flv.attribute2   = pn_max_id
                     WHERE     1 = 1
                           AND flv.flex_value_set_id IN
                                   (SELECT flex_value_set_id
                                      FROM apps.fnd_flex_value_sets
                                     WHERE flex_value_set_name =
                                           'XXD_AP_PAY_RECON_HIST_ID_VS')
                           AND flv.enabled_flag = 'Y'
                           AND flv.attribute1 = pn_organization_id
                           AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                                    SYSDATE)
                                           AND NVL (flv.end_date_active,
                                                    SYSDATE);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error While Updating Value Set' || SQLERRM);
                END;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error While Updating Value Set' || SQLERRM);
    END update_value_set;
END xxd_ap_recon_val_bl_pkg;
/
