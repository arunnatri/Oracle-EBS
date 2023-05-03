--
-- XXDO_XDOCK_UNPACK  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_XDOCK_UNPACK"
AS
    PROCEDURE xdock_unpack_main (errbuf                  OUT VARCHAR2,
                                 retcode                 OUT VARCHAR2,
                                 pn_order_number      IN     NUMBER,
                                 pv_parent_lpn        IN     VARCHAR2,
                                 pn_organization_id   IN     NUMBER);

    PROCEDURE unpack_order (pn_order_number      IN NUMBER,
                            pn_organization_id   IN NUMBER);

    PROCEDURE unpack_parent_lpn (pv_parent_lpn        IN VARCHAR2,
                                 pn_organization_id   IN NUMBER);
END XXDO_XDOCK_UNPACK;
/
