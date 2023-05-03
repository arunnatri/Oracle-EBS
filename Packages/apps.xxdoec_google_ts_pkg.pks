--
-- XXDOEC_GOOGLE_TS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOEC_GOOGLE_TS_PKG"
AS
    PROCEDURE shipments_by_day (p_site_id IN VARCHAR2, p_from_date IN DATE, p_to_date IN DATE
                                , p_resultset OUT SYS_REFCURSOR);

    PROCEDURE cancellations_by_day (p_site_id IN VARCHAR2, p_from_date IN DATE, p_to_date IN DATE
                                    , p_resultset OUT SYS_REFCURSOR);

    PROCEDURE get_org_id (p_brand     IN     VARCHAR2,
                          p_country   IN     VARCHAR2,
                          p_org_id       OUT INTEGER);
END XXDOEC_GOOGLE_TS_PKG;
/
