--
-- XXD_CE_CASHFLOW_UPD_VS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:07 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_CE_CASHFLOW_UPD_VS_PKG"
AS
    /*****************************************************************************************
      * Package         : XXD_CE_CASHFLOW_UPD_VS_PKG
      * Description     : This package is to update value set XXD_CE_LATEST_CASHFLOW_ID_VS
      *       post successful completion of 'Deckers CE Cashflow Statement Report'
      * Notes           :
      * Modification    :
      *-------------------------------------------------------------------------------------
      * Date         Version#      Name                       Description
      *-------------------------------------------------------------------------------------
      * 09-NOV-2020  1.0           Aravind Kannuri            Initial Version for CCR0008759
      *
      ***************************************************************************************/

    PROCEDURE update_value_set (pv_errbuf           OUT VARCHAR2,
                                pv_retcode          OUT NUMBER,
                                pv_module        IN     VARCHAR2,
                                pn_request_id    IN     NUMBER,
                                pn_criteria_id   IN     NUMBER)
    AS
        v_complete      BOOLEAN;
        lv_phase        VARCHAR2 (200);
        lv_status       VARCHAR2 (200);
        lv_dev_phase    VARCHAR2 (200);
        lv_dev_status   VARCHAR2 (200);
        lv_message      VARCHAR2 (200);
    BEGIN
        IF pv_module = 'CE'
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
                    --Update Latest Cashflow Id
                    UPDATE apps.fnd_flex_values_vl flv
                       SET flv.attribute1   = pn_criteria_id
                     WHERE     1 = 1
                           AND flv.flex_value_set_id IN
                                   (SELECT flex_value_set_id
                                      FROM apps.fnd_flex_value_sets
                                     WHERE flex_value_set_name =
                                           'XXD_CE_LATEST_CASHFLOW_ID_VS')
                           AND flv.enabled_flag = 'Y'
                           AND SYSDATE BETWEEN NVL (flv.start_date_active,
                                                    SYSDATE - 1)
                                           AND NVL (flv.end_date_active,
                                                    SYSDATE + 1);

                    COMMIT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Valueset updated - Criteria ID =>' || pn_criteria_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error While Updating Value Set' || SQLERRM);
                END;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Program Error, Skipped updation of Value Set');
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error While Updating Value Set' || SQLERRM);
    END update_value_set;
END XXD_CE_CASHFLOW_UPD_VS_PKG;
/
