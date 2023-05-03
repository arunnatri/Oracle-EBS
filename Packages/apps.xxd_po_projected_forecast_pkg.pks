--
-- XXD_PO_PROJECTED_FORECAST_PKG  (Package) 
--
--  Dependencies: 
--   FND_GLOBAL (Package)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:51 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_PROJECTED_FORECAST_PKG"
IS
      /****************************************************************************************************************
 NAME           : XXD_PO_SUPPLY_FORECAST_PKG
 REPORT NAME    : Deckers PO Supply Forecast Report

 REVISIONS:
 Date           Author             Version  Description
 ----------     ----------         -------  -------------------------------------------------------------------------
 30-NOV-2021    Damodara Gupta     1.0      This is the PO Supply Forecast Report. Report should fetch all Direct,
                                            Intercompany, JP TQ Open PO's and Open ASN's for given date/period range
 06-MAY-2022    Srinath Siricilla  2.0      CCR0009989
******************************************************************************************************************/

    gn_user_id       CONSTANT NUMBER := fnd_global.user_id;
    gn_request_id    CONSTANT NUMBER := fnd_global.conc_request_id;
    gv_delim_comma            VARCHAR2 (1) := ',';
    gn_error                  VARCHAR2 (4000);
    gn_delay_delivery_days    NUMBER;
    gn_delay_Intransit_days   NUMBER;               -- Added as per CCR0009989

    FUNCTION expected_receipt_dt_fnc (ACD IN DATE, PD IN DATE, CXF IN DATE)
        RETURN DATE;

    PROCEDURE main_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_run_mode IN VARCHAR2, pv_po_model IN VARCHAR2, pv_dummy IN VARCHAR2, pv_override IN VARCHAR2, pv_dummy1 IN VARCHAR2, pv_from_period IN VARCHAR2, pv_to_period IN VARCHAR2, pn_incld_past_due_days IN NUMBER, pn_delay_delivery_days IN NUMBER, pn_delay_Intransit_days IN NUMBER, -- Added as per CCR0009989
                                                                                                                                                                                                                                                                                                                                                                      pv_from_promised_date IN DATE, pv_to_promised_date IN DATE, pv_from_xf_date IN DATE, pv_to_xf_date IN DATE, pv_source_org IN VARCHAR2, pv_destination_org IN VARCHAR2
                        , pv_rate_date IN VARCHAR2, pv_rate_type IN VARCHAR2);
END xxd_po_projected_forecast_pkg;
/
