--
-- XXD_AR_INTERFACE_REF_UPD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_INTERFACE_REF_UPD_PKG"
AS
    /***************************************************************************************************************************************
    file name    : XXD_AR_INTERFACE_REF_UPD_PKG.pkb
    created on   : 04-SEP-2018
    created by   : INFOSYS
    purpose      : package specification used for the following
    1. To remove the reference line id for Credit Memos which are stuck in AR Interface with the error
    "The valid values for credit method for accounting rule are: PRORATE, LIFO and UNIT"
    **************************************************************************************************************************************
    Modification history:
    **************************************************************************************************************************************
    Version        Date        Author           Description
    ---------  ----------  ---------------  ------------------------------------
    1.0         04-SEP-2018     INFOSYS       1.Created
    ***************************************************************************************************************************************
    ***************************************************************************************************************************************/
    PROCEDURE ref_line_upd (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER)
    IS
        l_count           NUMBER := 0;
        l_iface_err_msg   VARCHAR2 (300) := NULL;
    BEGIN
        SELECT COUNT (1)
          INTO l_count
          FROM ra_interface_lines_all
         WHERE     reference_line_id IS NOT NULL
               AND interface_line_id IN
                       (SELECT a.interface_line_id
                          FROM ra_interface_errors_all a
                         WHERE a.MESSAGE_TEXT IN
                                   (SELECT ffvl.description
                                      FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvl
                                     WHERE     ffvs.flex_value_set_id =
                                               ffvl.flex_value_set_id
                                           AND ffvs.flex_value_set_name =
                                               'XXD_AR_ACCTG_RULE_ERR_MSG'
                                           AND ffvl.enabled_flag = 'Y'
                                           AND SYSDATE BETWEEN NVL (
                                                                   ffvl.start_date_active,
                                                                   SYSDATE)
                                                           AND NVL (
                                                                   ffvl.end_date_active,
                                                                   SYSDATE)));

        IF l_count > 0
        THEN
            UPDATE ra_interface_lines_all
               SET reference_line_id   = NULL
             WHERE interface_line_id IN
                       (SELECT a.interface_line_id
                          FROM ra_interface_errors_all a
                         WHERE a.MESSAGE_TEXT IN
                                   (SELECT ffvl.description
                                      FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffvl
                                     WHERE     ffvs.flex_value_set_id =
                                               ffvl.flex_value_set_id
                                           AND ffvs.flex_value_set_name =
                                               'XXD_AR_ACCTG_RULE_ERR_MSG'
                                           AND ffvl.enabled_flag = 'Y'
                                           AND SYSDATE BETWEEN NVL (
                                                                   ffvl.start_date_active,
                                                                   SYSDATE)
                                                           AND NVL (
                                                                   ffvl.end_date_active,
                                                                   SYSDATE)));

            COMMIT;
            fnd_file.put_line (fnd_file.LOG,
                               'Number of Records Updated:' || l_count);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error While Updating Reference Line ID:' || SQLERRM);
    END ref_line_upd;
END;
/
