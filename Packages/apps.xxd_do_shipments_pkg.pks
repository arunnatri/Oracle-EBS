--
-- XXD_DO_SHIPMENTS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxd_do_shipments_pkg
IS
    /************************************************************************
    * Module Name:   xxd_do_shipments_pkg
    * Description:   DO shipment data Transfer
    * Created By:    BT Technology Team
    * Creation Date:
    *************************************************************************
    * Version  * Author                       * Date             * Change Description
    *************************************************************************
    * 1.0      * BT Technology Team            *                * Initial version
    ************************************************************************/


    PROCEDURE shipment_load (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER);
END xxd_do_shipments_pkg;
/
