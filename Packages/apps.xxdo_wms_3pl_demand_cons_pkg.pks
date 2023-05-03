--
-- XXDO_WMS_3PL_DEMAND_CONS_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--   XXDO_WMS_3PL_ADJ_L (Table)
--
/* Formatted on 4/26/2023 4:17:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_WMS_3PL_DEMAND_CONS_PKG"
AS
    /*******************************************************************************
    * $Header$
    * Program Name : XXDO_WMS_3PL_DEMAND_CONS_PKG.pks
    * Language     : PL/SQL
    * Description  : This package is used for process the China/Hong Kong Ecommerce transactions(Sales Order/Returns).
    *                   It will Convert China/Hong Kong Ecommerce material transactions (Sales and Returns)  to Sales Order(s)
    *                   Once Create the SOs, it will do
    *                    1. Auto Pick Release and Ship confirm of China/Hong Kong Ecommerce Orders.
    *                    2. Auto Receipt of China Ecommerce Return Orders lines
    *                    3. Updating Transactions status of Adjustment records
    *                    4. Generate Oracle PL/SQL Alert for Exception Notification
    * History      :
    * This is copy from the original package XXDO_WMS_3PL_ADJ_CONV_PKG
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 10-Mar-2018  1.0        Viswanathan Pandian     Initial Version
    -- 23-Jul-2021  1.1        Damodara Gupta          Changes for CCR0009333
    *****************************************************************************************/
    --Global Variables
    gc_process_error      CONSTANT VARCHAR2 (1) := 'E';
    gc_process_import     CONSTANT VARCHAR2 (1) := 'I';            -- IMPORTED
    gc_process_shipped    CONSTANT VARCHAR2 (1) := 'T';      -- PICKE RELEASED
    gc_process_returned   CONSTANT VARCHAR2 (1) := 'R';            -- RETURNED
    gc_process_success    CONSTANT VARCHAR2 (1) := 'S';           -- SUCCESSED

    gc_package_name       CONSTANT VARCHAR2 (40)
                                       := 'XXDO_WMS_3PL_DEMAND_CONS_PKG' ;
    gc_ret_success        CONSTANT VARCHAR2 (1)
                                       := apps.fnd_api.g_ret_sts_success ;
    gc_ret_error          CONSTANT VARCHAR2 (1)
                                       := apps.fnd_api.g_ret_sts_error ;
    gn_org_id                      NUMBER := fnd_global.org_id;
    gn_user_id                     NUMBER := fnd_global.user_id;
    gn_login_id                    NUMBER := fnd_global.login_id;
    gc_order_source_nm             VARCHAR2 (100) := 'Ecomm Consumption';
    gc_order_mapping               VARCHAR2 (100) := 'XXDO_ECOM_ADJ_MAPPING';

    TYPE gt_adj_line_id_tbl
        IS TABLE OF xxdo.xxdo_wms_3pl_adj_l.adj_line_id%TYPE
        INDEX BY BINARY_INTEGER;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : create_sales_order
    -- Decription                : Invoke Order Import with Order Source
    --                             Once done Update the statge tables.
    -----------------------------------------------------------------------------------
    PROCEDURE create_sales_order (x_errbuf             OUT VARCHAR2,
                                  x_retcode            OUT VARCHAR2,
                                  p_order_source    IN     NUMBER,
                                  p_order_type_id   IN     NUMBER,
                                  -- Start changes for CCR0009333
                                  p_num_instances   IN     NUMBER);

    -- End changes for CCR0009333

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : book_order
    -- Decription                : Using API to Book Sales Orders.
    -----------------------------------------------------------------------------------
    PROCEDURE book_order (p_order_source_id   IN NUMBER,
                          p_order_type_id     IN NUMBER);

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : updating_process_status
    -- Decription                : updating the process status of stage table
    -----------------------------------------------------------------------------------
    PROCEDURE updating_process_status (p_process_status IN VARCHAR2, p_message IN VARCHAR2, p_adj_line_id IN NUMBER);

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : rcv_orders_process_prc
    -- Decription                : Post order import process automatic receipts needs to performed
    --                             to increment inventory for all line types
    --                               of Line Flow - Return with Receipt Only, No Credit in Awaiting Return status.
    --                            1. Insert return orders information into RCV interface tables
    --                            2. invoking procedure 'auto_receipt_retn_orders'
    PROCEDURE rcv_orders_process_prc (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_order_source_id IN NUMBER
                                      , p_order_type_id IN NUMBER);

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : generate_exception_notifaction
    -- Decription                : Generate the exception notifaction to China Ecommerce contact.
    -----------------------------------------------------------------------------------
    PROCEDURE generate_exception_notifaction (retcode   OUT VARCHAR2,
                                              errbuf    OUT VARCHAR2);

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : so_interface_load_prc
    -- Decription                : Converting China Ecommerce material transactions to sales orders
    --
    -- Parameters
    -- x_errbuf           OUT
    -- x_retcode          OUT
    -- p_order_source_id   IN
    -- p_order_type_id     IN
    -----------------------------------------------------------------------------------
    PROCEDURE so_interface_load_prc (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_order_source_id IN NUMBER
                                     , p_order_type_id IN NUMBER, -- Start changes for CCR0009333
                                                                  p_batch_size IN NUMBER, p_num_instances IN NUMBER);

    -- End changes for CCR0009333

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : main
    -- Decription                : The main procedure
    -- Parameters
    -- x_errbuf          OUT
    -- x_retcode         OUT
    -----------------------------------------------------------------------------------
    PROCEDURE main (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2);
END xxdo_wms_3pl_demand_cons_pkg;
/
