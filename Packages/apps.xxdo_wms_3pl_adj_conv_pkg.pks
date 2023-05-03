--
-- XXDO_WMS_3PL_ADJ_CONV_PKG  (Package) 
--
--  Dependencies: 
--   FND_API (Package)
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--   XXDO_WMS_3PL_ADJ_L (Table)
--
/* Formatted on 4/26/2023 4:17:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_WMS_3PL_ADJ_CONV_PKG"
AS
    /*******************************************************************************
    * $Header$
    * Program Name : XXDO_WMS_3PL_ADJ_CONV_PKG.pks
    * Language     : PL/SQL
    * Description  : This package is used for process the China/Hong Kong Ecommerce transactions(Sales Order/Returns).
    *                   It will Convert China/Hong Kong Ecommerce material transactions (Sales and Returns)  to Sales Order(s)
    *                   Once Create the SOs, it will do
    *                    1. Auto Pick Release and Ship confirm of China/Hong Kong Ecommerce Orders.
    *                    2. Auto Receipt of China Ecommerce Return Orders lines
    *                    3. Updating Transactions status of Adjustment records
    *                    4. Generate Oracle PL/SQL Alert for Exception Notification
    * History      :
    * 2-Jun-2015 Created as Initial
    * ------------------------------------------------------------------------
    * WHO                        WHAT               WHEN
    * --------------         ---------------------- ---------------
    * BT Technology Team      Initial                 02-Jun-2015
    *
    *
    *******************************************************************************/
    --Global Variables
    gc_process_error      CONSTANT VARCHAR2 (1) := 'E';
    gc_process_import     CONSTANT VARCHAR2 (1) := 'I';            -- IMPORTED
    gc_process_shipped    CONSTANT VARCHAR2 (1) := 'T';      -- PICKE RELEASED
    gc_process_returned   CONSTANT VARCHAR2 (1) := 'R';            -- RETURNED
    gc_process_success    CONSTANT VARCHAR2 (1) := 'S';           -- SUCCESSED

    gc_package_name       CONSTANT VARCHAR2 (40)
                                       := 'XXDO_WMS_3PL_ADJ_CONV_PKG' ;
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
    --
    -- Parameters
    -- x_errbuf                 OUTPUT
    -- x_retcode                 OUTPUT
    -- p_order_source            INPUT
    -- p_order_type_id          INPUT
    -- Modification History
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE create_sales_order (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_order_source IN NUMBER
                                  , p_order_type_id IN NUMBER);

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : book_order
    -- Decription                : Using API to Book Sales Orders.
    --
    --
    -- Parameters
    -- p_order_source_id IN
    -- p_order_type_id   IN
    --
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE book_order (p_order_source_id   IN NUMBER,
                          p_order_type_id     IN NUMBER);

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : updating_process_status
    -- Decription                : updating the process status of stage table
    --
    --
    -- Parameters
    -- p_process_status        INPUT
    -- p_message              INPUT
    -- p_adj_line_id             INPUT
    -- Comments
    -- gv_process_error   'E'
    -- gv_process_import  'I'
    -- gv_process_returned 'R'
    --
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE updating_process_status (p_process_status IN VARCHAR2, p_message IN VARCHAR2, p_adj_line_id IN NUMBER);

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : pick_release_prc
    -- Decription                : Auto Pick Release and Ship confirm of China/Hong Kong Ecommerce Orders.
    --                             1. Using wsh_delivery_details_pub.autocreate_deliveries to create delivery
    --                             2. Invoking Pick_Release to process pick release
    --                             3. Invoking Ship_confirm to Confirm the Shipping Sales Orders
    -- Parameters
    -- x_errbuf          OUT
    -- x_retcode         OUT
    -- p_order_source_id IN
    -- p_order_type_id   IN
    --
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE pick_release_prc (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_order_source_id IN NUMBER
                                , p_order_type_id IN NUMBER);

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : rcv_orders_process_prc
    -- Decription                : Post order import process automatic receipts needs to performed
    --                             to increment inventory for all line types
    --                               of Line Flow - Return with Receipt Only, No Credit in Awaiting Return status.
    --                            1. Insert return orders information into RCV interface tables
    --                            2. invoking procedure 'auto_receipt_retn_orders'
    -- Parameters
    -- x_errbuf          OUT
    -- x_retcode         OUT
    -- p_order_source_id IN
    -- p_order_type_id   IN
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : ship_confirm
    -- Decription                : Using API to do the Shipping Confirm
    -- Parameters
    -- p_delivery_id          IN
    -- x_return_status        OUT
    --
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE ship_confirm (p_delivery_id     IN     NUMBER,
                            x_return_status      OUT VARCHAR2);

    PROCEDURE rcv_orders_process_prc (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_order_source_id IN NUMBER
                                      , p_order_type_id IN NUMBER);

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : auto_receipt_retn_orders
    -- Decription                : Receiving Transaction Processor Concurrent program to process interface records
    --
    -- Parameters
    -- p_org_id          IN
    -- x_request_id      OUT
    -- x_return_status   OUT
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE auto_receipt_retn_orders (p_org_id IN NUMBER, x_request_id OUT NUMBER, x_return_status OUT VARCHAR2);

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : generate_exception_notifaction
    -- Decription                : Generate the exception notifaction to China Ecommerce contact.
    --                             1. If there are adjustment records from 3PL (in staging table)
    --                                  that has not been flipped into an order (stuck there for more than 3 days)
    --                              2. If auto pick /ship process fails for the china ecommerce shipment records
    --                             3. If auto receipt process fails for the china ecommerce return records
    --                              4. If ship only sales orders are open / not processed for more than a couple of days
    -- Parameters
    -- retcode          OUT
    -- errbuf            OUT
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
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
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE so_interface_load_prc (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_order_source_id IN NUMBER
                                     , p_order_type_id IN NUMBER);

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : main
    -- Decription                : The main procedure
    --
    -- Parameters
    -- x_errbuf          OUT
    -- x_retcode         OUT
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE main (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2);
END XXDO_WMS_3PL_ADJ_CONV_PKG;
/
