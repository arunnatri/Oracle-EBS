--
-- XXDO_WMS_QR_PROCESSING_API  (Package) 
--
--  Dependencies: 
--   XMLTYPE (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_WMS_QR_PROCESSING_API"
AS
    FUNCTION qr_http_strip_fnc (p_http_input_str IN VARCHAR2)
        RETURN VARCHAR2;

    PROCEDURE xxdo_qr_get_code_prc (QueryType         IN            VARCHAR2,
                                    QueryValue        IN            VARCHAR2,
                                    x_xml_type           OUT        XMLTYPE,
                                    x_return_status      OUT NOCOPY VARCHAR2,
                                    x_error_message      OUT NOCOPY VARCHAR2);

    PROCEDURE qr_api_main (x_return_status OUT NOCOPY VARCHAR2, x_error_message OUT NOCOPY VARCHAR2, p_qr_input_str IN VARCHAR2
                           , p_query_type IN VARCHAR2);

    PROCEDURE xxdo_populate_serial_temp_prc (x_return_status OUT NOCOPY VARCHAR2, x_error_message OUT NOCOPY VARCHAR2, p_organization_id IN NUMBER
                                             , p_include_lpn_context_4_5 IN VARCHAR2 DEFAULT 'Y', p_trans_start_date IN VARCHAR2, p_trans_end_date IN VARCHAR2);

    PROCEDURE xxdo_populate_serial_temp_prc (
        errbuf                         OUT NOCOPY VARCHAR2,
        retcode                        OUT NOCOPY NUMBER,
        p_organization_id           IN            NUMBER,
        p_include_lpn_context_4_5   IN            VARCHAR2 DEFAULT 'Y',
        p_trans_start_date          IN            VARCHAR2,
        p_trans_end_date            IN            VARCHAR2,
        p_conc_program_flag         IN            VARCHAR2 DEFAULT 'Y');
END XXDO_WMS_QR_PROCESSING_API;
/
