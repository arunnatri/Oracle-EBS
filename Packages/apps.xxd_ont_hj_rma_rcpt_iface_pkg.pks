--
-- XXD_ONT_HJ_RMA_RCPT_IFACE_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:23:24 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_HJ_RMA_RCPT_IFACE_PKG"
AS
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxd_ont_hj_rma_rcpt_iface_pkg
    --
    -- Description  :  This is package  for WMS to EBS Return Receiving Inbound Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date           Author                 Version     Description
    -- ------------   -----------------      -------     --------------------------------
    -- 20-Jan-2020    GJensen                1.0         Created
    -- ***************************************************************************
    gv_rma_receipt_msg_type      VARCHAR2 (30) := '701';

    gn_request_id                NUMBER := fnd_global.conc_request_id;
    gn_user_id                   NUMBER := fnd_global.user_id;
    gn_login_id                  NUMBER := fnd_global.login_id;

    gn_debug                     NUMBER := 0;
    gd_sysdate                   DATE := SYSDATE;

    --Stage table default values
    gv_whs_id           CONSTANT VARCHAR2 (20) := 'US1';
    gv_subinventory     CONSTANT VARCHAR2 (50) := 'RETURNS';
    gd_receipt_date     CONSTANT DATE := SYSDATE;
    gv_item_number      CONSTANT VARCHAR2 (20) := 'NULL_ITEM';
    gn_employee_id      CONSTANT NUMBER := 1879;                   --BATCH.WMS
    gn_empployee_name   CONSTANT VARCHAR2 (20) := 'BATCH.WMS';

    /*---------------------------------------------------------------
       Public procedure to process RMAs from the styaging tables to EBS

      Error parameters
      p_errbuf
      p_retcode

      Parameters
        p_wh_code                  VARCHAR2
         p_rma_num                 VARCHAR2
         p_source                  VARCHAR2
         p_destination             VARCHAR2
         p_purge_days              NUMBER
         p_debug                   VARCHAR2

      ----------------------------------------------------------------*/

    PROCEDURE Process_rma_interface (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_wh_code IN VARCHAR2, p_rma_num IN VARCHAR2, p_source IN VARCHAR2 DEFAULT 'WMS', p_destination IN VARCHAR2 DEFAULT 'EBS'
                                     , p_debug IN VARCHAR2 DEFAULT 'Y');

    PROCEDURE remove_rma_overreceipt_holds (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_rma_number IN NUMBER);

    PROCEDURE archive_rma_stage_data (p_errbuf    OUT VARCHAR2,
                                      p_retcode   OUT NUMBER);
END;
/
