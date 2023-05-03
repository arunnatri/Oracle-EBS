--
-- XXD_TRO_DUTY_STATUS_REP_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_TRO_DUTY_STATUS_REP_PKG"
AS
    /***********************************************************************************
     *$header :                                                                        *
     *                                                                                 *
     * AUTHORS : ANM                                                                   *
     *                                                                                 *
     * PURPOSE : Used for Duty Platform Status Report                                  *
     *                                                                                 *
     * PARAMETERS :                                                                    *
     *                                                                                 *
     * DATE : 01-Jan-2022                                                              *
     *                                                                                 *
     * Assumptions:                                                                    *
     *                                                                                 *
     *                                                                                 *
     * History                                                                         *
     * Vsn   Change Date Changed By           Change Description                       *
     * ----- ----------- -------------------  -------------------------------------    *
     * 1.0   01-Jan-2022   ANM    Initial Creation                                     *
     **********************************************************************************/

    gn_user_id      CONSTANT NUMBER := fnd_global.user_id;
    gn_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;
    gn_error        CONSTANT NUMBER := 2;
    gv_delim_pipe            VARCHAR2 (1) := '|';

    PROCEDURE main_detail (errbuf            OUT VARCHAR2,
                           retcode           OUT NUMBER,
                           pv_file_name   IN     VARCHAR2,
                           pv_from_date   IN     VARCHAR2,
                           pv_to_date     IN     VARCHAR2,
                           pv_coo         IN     VARCHAR2,
                           pv_COD         IN     VARCHAR2,
                           pv_status      IN     VARCHAR2,
                           pv_sku_level   IN     VARCHAR2);
END;
/
