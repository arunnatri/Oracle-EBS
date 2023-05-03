--
-- XXDO_WMS_QR_PROCESSING_API  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_WMS_QR_PROCESSING_API"
AS
    FUNCTION qr_http_strip_fnc (p_http_input_str IN VARCHAR2)
        RETURN VARCHAR2
    IS
        v_new_value   VARCHAR2 (1000) := NULL;
    BEGIN
        IF UPPER (p_http_input_str) LIKE '%HTTP://%'
        THEN
            v_new_value   :=
                SUBSTR (p_http_input_str,
                        INSTR (p_http_input_str, '/', -1) + 1);
        ELSIF UPPER (p_http_input_str) LIKE '%WWW.%'
        THEN
            v_new_value   :=
                SUBSTR (p_http_input_str,
                        INSTR (p_http_input_str, '/', -1) + 1);
        ELSE
            v_new_value   := p_http_input_str;
        END IF;

        RETURN v_new_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END qr_http_strip_fnc;

    PROCEDURE xxdo_qr_get_code_prc (QueryType         IN            VARCHAR2,
                                    QueryValue        IN            VARCHAR2,
                                    x_xml_type           OUT        XMLTYPE,
                                    x_return_status      OUT NOCOPY VARCHAR2,
                                    x_error_message      OUT NOCOPY VARCHAR2)
    IS
        --// URL to call
        SOAP_URL                 VARCHAR2 (1000);

        --// SOAP envelope template, containing $ substitution variables
        SOAP_ENVELOPE   CONSTANT VARCHAR2 (32767)
            := '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:qrin="http://xmlns.oracle.com/ORInquiryProcess/QRInquiry/QRInquiry">
<soapenv:Header/>
<soapenv:Body>
<qrin:process>
<qrin:Type>$QTYPE</qrin:Type>
<qrin:Value>$QVALUE</qrin:Value>
</qrin:process>
</soapenv:Body>
</soapenv:Envelope>' ;

        --// we'll identify ourselves using an IE9/Windows7 generic browser signature
        -- C_USER_AGENT CONSTANT VARCHAR2(4000) := 'Mozilla/5.0 (compatible; MSIE 9.0; Windows NT 6.1; Trident/5.0)';

        --// these variables need to be set if web access
        --// is via a proxy server
        proxyServer              VARCHAR2 (20) DEFAULT NULL;
        proxyUser                VARCHAR2 (20) DEFAULT NULL;
        proxyPass                VARCHAR2 (20) DEFAULT NULL;

        --// our local variables
        soapEnvelope             VARCHAR2 (32767);
        proxyURL                 VARCHAR2 (4000);
        request                  UTL_HTTP.req;
        response                 UTL_HTTP.resp;
        buffer                   VARCHAR2 (32767);
        soapResponse             CLOB;
        xmlResponse              XMLTYPE;
        eof                      BOOLEAN;

        CERT_PATH                VARCHAR2 (200);
        CERT_PWD                 VARCHAR2 (50);
    BEGIN
        --FETCH THE SOAP URL FROM LOOKUP TABLE
        BEGIN
            SELECT description
              INTO SOAP_URL
              FROM apps.fnd_lookup_values
             WHERE     lookup_type = 'XXDO_QR_API_WEB_SERVICES'
                   AND lookup_code = 'SOAP_URL'
                   AND language = USERENV ('LANG')
                   AND view_application_id = 3;
        EXCEPTION
            WHEN OTHERS
            THEN
                SOAP_URL   := NULL;
        END;

        IF UPPER (SOAP_URL) LIKE 'HTTPS%'
        THEN
            --FETCH THE HTTPS CERTIFICATE PATH AND PASSWORD FROM LOOKUP TABLE
            BEGIN
                SELECT description
                  INTO CERT_PATH
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'XXDO_QR_API_WEB_SERVICES'
                       AND lookup_code = 'CERT_PATH'
                       AND language = USERENV ('LANG')
                       AND view_application_id = 3;

                SELECT description
                  INTO CERT_PWD
                  FROM apps.fnd_lookup_values
                 WHERE     lookup_type = 'XXDO_QR_API_WEB_SERVICES'
                       AND lookup_code = 'CERT_PWD'
                       AND language = USERENV ('LANG')
                       AND view_application_id = 3;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CERT_PATH   := NULL;
                    CERT_PWD    := NULL;
            END;

            IF CERT_PATH IS NOT NULL AND CERT_PWD IS NOT NULL
            THEN
                --SAMPLE : utl_http.set_wallet('file:' || '/home/oracle/wallet', 'password123');
                UTL_HTTP.set_wallet ('file:' || CERT_PATH, CERT_PWD);
            END IF;
        END IF;


        IF SOAP_URL IS NOT NULL
        THEN
            --// create the SOAP envelope
            soapEnvelope      := REPLACE (SOAP_ENVELOPE, '$QTYPE', QueryType);
            soapEnvelope      := REPLACE (soapEnvelope, '$QVALUE', QueryValue);

            --// our "browser" settings
            UTL_HTTP.set_response_error_check (TRUE);
            UTL_HTTP.set_detailed_excp_support (TRUE);
            UTL_HTTP.set_cookie_support (TRUE);
            UTL_HTTP.set_transfer_timeout (10);
            UTL_HTTP.set_follow_redirect (3);
            UTL_HTTP.set_persistent_conn_support (TRUE);

            --// configure for web proxy access if applicable
            IF proxyServer IS NOT NULL
            THEN
                proxyURL   := 'http://' || proxyServer;

                IF (proxyUser IS NOT NULL) AND (proxyPass IS NOT NULL)
                THEN
                    proxyURL   :=
                        REPLACE (
                            proxyURL,
                            'http://',
                            'http://' || proxyUser || ':' || proxyPass || '@');
                END IF;

                UTL_HTTP.set_proxy (proxyURL, NULL);
            END IF;

            --// make the POST call to the web service
            request           :=
                UTL_HTTP.begin_request (SOAP_URL,
                                        'POST',
                                        UTL_HTTP.HTTP_VERSION_1_1);
            --    utl_http.set_header( request, 'User-Agent', C_USER_AGENT );
            UTL_HTTP.set_header (request,
                                 'Content-Type',
                                 'text/xml; charset=utf-8');
            -- utl_http.set_header( request, 'Content-Type', 'application/soap+xml;charset=UTF-8' );
            UTL_HTTP.set_header (request,
                                 'Content-Length',
                                 LENGTH (soapEnvelope));

            --utl_http.set_header( request, 'SoapAction', 'https://www.sekuworks.net/wsQueryService/GetCodeInstance' );
            IF QueryType = 'CODE'
            THEN
                UTL_HTTP.set_header (request,
                                     'SoapAction',
                                     'GetCodeInstance');
            ELSE
                UTL_HTTP.set_header (request,
                                     'SoapAction',
                                     'GetContainerInstance');
            END IF;

            UTL_HTTP.write_text (request, soapEnvelope);

            --// read the web service HTTP response
            response          := UTL_HTTP.get_response (request);

            DBMS_LOB.CreateTemporary (soapResponse, TRUE);
            eof               := FALSE;

            LOOP
                EXIT WHEN eof;

                BEGIN
                    UTL_HTTP.read_line (response, buffer, TRUE);

                    IF LENGTH (buffer) > 0
                    THEN
                        DBMS_LOB.WriteAppend (soapResponse,
                                              LENGTH (buffer),
                                              buffer);
                    END IF;
                EXCEPTION
                    WHEN UTL_HTTP.END_OF_BODY
                    THEN
                        eof   := TRUE;
                END;
            END LOOP;

            UTL_HTTP.end_response (response);

            --// as the SOAP responds with XML, we convert
            --// the response to XML
            xmlResponse       := XmlType.createXML (soapResponse);
            DBMS_LOB.FreeTemporary (soapResponse);

            x_xml_type        := xmlResponse;
            x_return_status   := 'S';
            x_error_message   := '';
        ELSE
            x_return_status   := 'E';
            x_error_message   :=
                'Please set-up the SOAP URL lookup value under the Oracle EBS Lookup type "XXDO_QR_API_WEB_SERVICES"';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF soapResponse IS NOT NULL
            THEN
                DBMS_LOB.FreeTemporary (soapResponse);
            END IF;

            x_return_status   := 'E';
            x_error_message   :=
                'SOAP Call from "xxdo_wms_qr_processing_api.qr_api_main" PL/SQL API failed to receive response, Please contact IT Team';
    END xxdo_qr_get_code_prc;

    PROCEDURE qr_inquiry_web_services (p_query_type IN VARCHAR2, p_query_value IN VARCHAR2, x_return_status OUT NOCOPY VARCHAR2
                                       , x_error_message OUT NOCOPY VARCHAR2)
    IS
        lx_xmltype_out           SYS.XMLTYPE;
        -- lc_return              CLOB;
        lv_query_type            VARCHAR2 (20);
        lv_query_value           VARCHAR2 (500) := NULL;
        lv_result_code           VARCHAR2 (500) := NULL;
        lv_code_type             VARCHAR2 (500) := NULL;
        lv_status_code           VARCHAR2 (500) := NULL;
        lv_package_code_value    VARCHAR2 (500) := NULL;
        lv_product_code_value    VARCHAR2 (500) := NULL;
        lv_upc                   VARCHAR2 (500) := NULL;
        lv_quality_code          VARCHAR2 (500) := NULL;
        lv_container_qr_code     VARCHAR2 (500) := NULL;
        lv_container_ucc         VARCHAR2 (500) := NULL;
        lv_container_type_code   VARCHAR2 (500) := NULL;
        lv_trans_identifier      VARCHAR2 (500) := NULL;
        lv_quantity              VARCHAR2 (500) := NULL;
        lv_unit_type_code        VARCHAR2 (500) := NULL;
        lv_customer_code         VARCHAR2 (500) := NULL;
        lv_location_name         VARCHAR2 (500) := NULL;
        lv_location_code         VARCHAR2 (500) := NULL;
        lv_location_address1     VARCHAR2 (500) := NULL;
        lv_location_address2     VARCHAR2 (500) := NULL;
        lv_location_city         VARCHAR2 (500) := NULL;
        lv_location_state        VARCHAR2 (500) := NULL;
        lv_location_province     VARCHAR2 (500) := NULL;
        lv_location_postalcode   VARCHAR2 (500) := NULL;
        lv_location_country      VARCHAR2 (500) := NULL;
        l_ns                     VARCHAR2 (500) := NULL;
        v_xpath_Code             VARCHAR2 (200) := NULL;
        v_xpath_Container        VARCHAR2 (200) := NULL;
        v_item_count             NUMBER;
        v_record_count           NUMBER;
    ---------------------------------
    -- Beginning of the procedure
    --------------------------------
    BEGIN
        lv_query_type    := p_query_type;
        lv_query_value   := p_query_value;

        l_ns             :=
            'xmlns:a="http://schemas.xmlsoap.org/soap/envelope/" xmlns:b="http://xmlns.oracle.com/ORInquiryProcess/QRInquiry/QRInquiry"';
        v_xpath_Code     := '/a:Envelope/a:Body/b:GetCodeInstanceResponse';
        v_xpath_Container   :=
            '/a:Envelope/a:Body/b:GetContainerInstanceResponse';

        --DBMS_OUTPUT.PUT_LINE ('BEFORE CALL TO XXDO_QR_GET_CODE_PRC'         || '-'         || lv_query_type         || '-'         || lv_query_value);

        XXDO_WMS_QR_PROCESSING_API.XXDO_QR_GET_CODE_PRC (
            QueryType         => lv_query_type,
            QueryValue        => lv_query_value,
            x_xml_type        => lx_xmltype_out,
            x_return_status   => x_return_status,
            x_error_message   => x_error_message); --DBMS_OUTPUT.PUT_LINE ('AFTER CALL TO XXDO_QR_GET_CODE_FNC');

        ----------------------------------------
        -- If the XML TYPE OUT IS NOT NULL then
        -- the result is good and debugging the
        -- same
        ----------------------------------------
        IF lx_xmltype_out IS NOT NULL AND x_return_status = 'S'
        THEN
            -- Storing the return values
            ----------------------------
            --lc_return := xmltype.getclobval(lx_xmltype_out);

            --DBMS_OUTPUT.PUT_LINE ('CALL TO XXDO_QR_GET_CODE_FNC IS SUCCESSFUL');

            IF (lx_xmltype_out.EXISTSNODE ('/a:Envelope/a:Body', l_ns) > 0)
            THEN
                IF lv_query_type = 'UCC'
                THEN
                    SELECT COUNT (*)
                      INTO v_item_count
                      FROM TABLE (XMLSEQUENCE (EXTRACT (lx_xmltype_out, v_xpath_Container || '/b:ContainerItemInstance/b:ContainerItemCollection', l_ns)));

                    --DBMS_OUTPUT.PUT_LINE ('CountNode = ' || v_item_count);

                    IF v_item_count = 0
                    THEN
                        SELECT EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:ResultCode', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:StatusCode', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:ContainerQRCode', l_ns),
                               EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:UCC', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:Quantity', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:UnitTypeCode', l_ns),
                               EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:TransactionIdentifier', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:ContainerTypeCode', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:CustomerCode', l_ns),
                               EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:LocationCode', l_ns)
                          INTO lv_result_code, lv_status_code, lv_container_qr_code, lv_container_ucc,
                                             lv_quantity, lv_unit_type_code, lv_trans_identifier,
                                             lv_container_type_code, lv_customer_code, lv_location_code
                          FROM DUAL;

                        --DBMS_OUTPUT.PUT_LINE ('BEFORE INSERT INTO TEMP TABLE');

                        DECLARE
                            V_COUNT   NUMBER := 0;
                        BEGIN
                            INSERT INTO xxdo.xxdo_ucc_inquiry_gtmp (
                                            qr_in_type,
                                            qr_in_value,
                                            result_code,
                                            status_code,
                                            container_qr_code,
                                            ucc,
                                            quantity,
                                            unit_type_code,
                                            transaction_identifier,
                                            container_type_code,
                                            customer_code,
                                            location_code,
                                            container_item_col_seq,
                                            product_code_value,
                                            upc,
                                            quality_code,
                                            package_code_value)
                                SELECT p_query_type, p_query_value, lv_result_code,
                                       lv_status_code, lv_container_qr_code, lv_container_ucc,
                                       lv_quantity, lv_unit_type_code, lv_trans_identifier,
                                       lv_container_type_code, lv_customer_code, lv_location_code,
                                       v_item_count, NULL, NULL,
                                       NULL, NULL
                                  FROM DUAL;

                            SELECT COUNT (*)
                              INTO V_COUNT
                              FROM xxdo.xxdo_ucc_inquiry_gtmp;
                        --DBMS_OUTPUT.PUT_LINE ( 'INSERT INTO TEMP TABLE SUCCESSFUL ==>' || V_COUNT);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        --DBMS_OUTPUT.PUT_LINE ('ERROR INSERTING DATA INTO INTO TEMP TABLE');
                        END;

                        x_return_status   := 'S';
                        x_error_message   := '';
                    ELSIF v_item_count > 0
                    THEN
                        FOR R1 IN 1 .. v_item_count
                        LOOP
                            SELECT EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:ResultCode', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:StatusCode', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:ContainerQRCode', l_ns),
                                   EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:UCC', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:Quantity', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:UnitTypeCode', l_ns),
                                   EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:TransactionIdentifier', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:ContainerTypeCode', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:CustomerCode', l_ns),
                                   EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:LocationCode', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:ContainerItemInstance/b:ContainerItemCollection[' || R1 || ']/b:ProductCodeValue', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:ContainerItemInstance/b:ContainerItemCollection[' || R1 || ']/b:UPC', l_ns),
                                   EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:ContainerItemInstance/b:ContainerItemCollection[' || R1 || ']/b:QualityCode', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Container || '/b:ContainerItemInstance/b:ContainerItemCollection[' || R1 || ']/b:PackageCodeValue', l_ns)
                              INTO lv_result_code, lv_status_code, lv_container_qr_code, lv_container_ucc,
                                                 lv_quantity, lv_unit_type_code, lv_trans_identifier,
                                                 lv_container_type_code, lv_customer_code, lv_location_code,
                                                 lv_product_code_value, lv_upc, lv_quality_code,
                                                 lv_package_code_value
                              FROM DUAL;

                            --DBMS_OUTPUT.PUT_LINE ('BEFORE INSERT INTO TEMP TABLE');

                            BEGIN
                                INSERT INTO xxdo.xxdo_ucc_inquiry_gtmp (
                                                qr_in_type,
                                                qr_in_value,
                                                result_code,
                                                status_code,
                                                container_qr_code,
                                                ucc,
                                                quantity,
                                                unit_type_code,
                                                transaction_identifier,
                                                container_type_code,
                                                customer_code,
                                                location_code,
                                                container_item_col_seq,
                                                product_code_value,
                                                upc,
                                                quality_code,
                                                package_code_value)
                                    SELECT p_query_type, p_query_value, lv_result_code,
                                           lv_status_code, lv_container_qr_code, lv_container_ucc,
                                           lv_quantity, lv_unit_type_code, lv_trans_identifier,
                                           lv_container_type_code, lv_customer_code, lv_location_code,
                                           R1, lv_product_code_value, lv_upc,
                                           NVL (lv_quality_code, 'U'), lv_package_code_value
                                      FROM DUAL;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            --DBMS_OUTPUT.PUT_LINE ('ERROR INSERTING DATA INTO INTO TEMP TABLE');
                            END;
                        END LOOP;

                        SELECT COUNT (*)
                          INTO v_record_count
                          FROM xxdo.xxdo_ucc_inquiry_gtmp;

                        --DBMS_OUTPUT.PUT_LINE ('INSERT INTO TEMP TABLE SUCCESSFUL ==>' || v_record_count);

                        x_return_status   := 'S';
                        x_error_message   := '';
                    END IF;                                   -- v_count check
                ELSIF lv_query_type = 'CODE'
                THEN
                    SELECT EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:ResultCode', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:CodeType', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:StatusCode', l_ns),
                           EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:PackageCodeValue', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:ProductCodeValue', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:UPC', l_ns),
                           EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:QualityCode', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:ContainerQRCode', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:ContainerUCC', l_ns),
                           EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:CustomerCode', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:LocationName', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:Address1', l_ns),
                           EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:Address2', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:City', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:StateCode', l_ns),
                           EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:Province', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:PostalCode', l_ns), EXTRACTVALUE (lx_xmltype_out, v_xpath_Code || '/b:CountryCode', l_ns)
                      INTO lv_result_code, lv_code_type, lv_status_code, lv_package_code_value,
                                         lv_product_code_value, lv_upc, lv_quality_code,
                                         lv_container_qr_code, lv_container_ucc, lv_customer_code,
                                         lv_location_name, lv_location_address1, lv_location_address2,
                                         lv_location_city, lv_location_state, lv_location_province,
                                         lv_location_postalcode, lv_location_country
                      FROM DUAL;

                    --DBMS_OUTPUT.PUT_LINE ('ResultCode = ' || lv_Result_Code);
                    --DBMS_OUTPUT.PUT_LINE ('Container QR Code = ' || lv_container_qr_code);

                    --DBMS_OUTPUT.PUT_LINE ('BEFORE INSERT INTO TEMP TABLE');

                    DECLARE
                        V_COUNT   NUMBER := 0;
                    BEGIN
                        INSERT INTO xxdo.xxdo_qr_inquiry_gtmp (
                                        qr_in_type,
                                        qr_in_value,
                                        result_code,
                                        code_type,
                                        status_code,
                                        package_code_value,
                                        product_code_value,
                                        upc,
                                        quality_code,
                                        container_qr_code,
                                        container_ucc,
                                        customer_code,
                                        location_name,
                                        address1,
                                        address2,
                                        city,
                                        state_code,
                                        province,
                                        postal_code,
                                        country_code)
                            SELECT p_query_type, p_query_value, lv_result_code,
                                   lv_code_type, lv_status_code, lv_package_code_value,
                                   lv_product_code_value, lv_upc, lv_quality_code,
                                   lv_container_qr_code, lv_container_ucc, lv_customer_code,
                                   lv_location_name, lv_location_address1, lv_location_address2,
                                   lv_location_city, lv_location_state, lv_location_province,
                                   lv_location_postalcode, lv_location_country
                              FROM DUAL;

                        SELECT COUNT (*)
                          INTO V_COUNT
                          FROM xxdo.xxdo_qr_inquiry_gtmp;
                    --DBMS_OUTPUT.PUT_LINE ('INSERT INTO TEMP TABLE SUCCESSFUL ==>' || V_COUNT);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    --DBMS_OUTPUT.PUT_LINE ('ERROR INSERTING DATA INTO INTO TEMP TABLE');
                    END;

                    x_return_status   := 'S';
                    x_error_message   := '';
                END IF;                                     --QUERY TYPE CHECK
            ELSE
                x_return_status   := 'E';
                x_error_message   :=
                    'Invalid "Query Type" parameter passed, please use "UCC" or "CODE" as the parameter value';
            --DBMS_OUTPUT.PUT_LINE ('Invalid "Query Type" parameter passed, please use "UCC" or "CODE" as the parameter value');
            END IF;
        ELSE
            x_return_status   := 'E';
        --DBMS_OUTPUT.PUT_LINE ('SOAP call return was error');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := 'S';
            x_error_message   :=
                'Unknown Exception inside the call to qr_inquiry_web_services';
    --DBMS_OUTPUT.PUT_LINE (SQLCODE || '-' || SQLERRM);
    END qr_inquiry_web_services;

    /*DEVELOPER NOTE : PL/SQL PROGRAM WHICH CALLS THIS  API SHOULD  HAVE A EXPLICIT COMMIT ISSUED AFTER MAKING THE CALL
    THIS WILL ENSURE THAT THE GLOBAL TEMP TABLES ARE INITIALIZED AUTOMATICALLY AFTER EACH CALL*/

    PROCEDURE qr_api_main (x_return_status OUT NOCOPY VARCHAR2, x_error_message OUT NOCOPY VARCHAR2, p_qr_input_str IN VARCHAR2
                           , p_query_type IN VARCHAR2)
    IS
        v_query_value   VARCHAR2 (1000);
    BEGIN
        IF p_query_type NOT IN ('CODE', 'UCC')
        THEN
            x_return_status   := 'E';
            x_error_message   :=
                'Invalid "Query Type" parameter passed, please use "UCC" or "CODE" as the parameter value';
        --DBMS_OUTPUT.PUT_LINE ('Invalid "Query Type" parameter passed, please use "UCC" or "CODE" as the parameter value');
        ELSE
            --Call below function to strip out the HTTP string and fetch the code value
            v_query_value   := qr_http_strip_fnc (p_qr_input_str);

            --DBMS_OUTPUT.PUT_LINE ('BEFORE CALL TO QR INQUIRY WEB SERVICES');
            --CALL TO WEB SERVICES API
            qr_inquiry_web_services (p_query_type => p_query_type, p_query_value => v_query_value, x_return_status => x_return_status
                                     , x_error_message => x_error_message);
        END IF;
    --DBMS_OUTPUT.PUT_LINE ('AFTER CALL TO QR INQUIRY WEB SERVICES :'         || x_return_status      || '-'         || x_error_message);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := 'E';
            x_error_message   :=
                'Unknown exception occured in the call to xxdo_wms_qr_processing_api.qr_api_main" PL/SQL API';
    END qr_api_main;

    PROCEDURE insert_xxdo_serial_temp_prc (x_return_status OUT NOCOPY VARCHAR2, x_error_message OUT NOCOPY VARCHAR2, p_lpn_number IN VARCHAR2
                                           , p_inventory_item_id IN NUMBER, p_source_reference_id IN NUMBER, p_organization_id IN NUMBER)
    IS
        CURSOR UCC_INQUIRY_GTMP_CUR IS
              SELECT *
                FROM xxdo.xxdo_ucc_inquiry_gtmp xuig
               WHERE     qr_in_value = p_lpn_number
                     AND package_code_value IS NOT NULL
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxdo_serial_temp
                               WHERE     serial_number =
                                         xuig.package_code_value
                                     AND organization_id = p_organization_id)
            ORDER BY CONTAINER_ITEM_COL_SEQ ASC;

        sn_rec          apps.xxdo_serialization.sn_rec;
        l_debug_level   NUMBER := 0;
        v_status_id     NUMBER;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Inside the procedure insert_xxdo_serial_temp_prc');

        FOR UCC_INQUIRY_GTMP_REC IN UCC_INQUIRY_GTMP_CUR
        LOOP
            --fnd_file.put_line (fnd_file.LOG, 'Inside the insert procedure SERIAL NUMBER IS: '|| ucc_inquiry_gtmp_rec.package_code_value);


            BEGIN
                SELECT TO_NUMBER (lookup_code)
                  INTO v_status_id
                  FROM fnd_lookup_values flv
                 WHERE     flv.lookup_type = 'XXDO_SERIAL_TEMP_STATUS_ID'
                       AND language = USERENV ('LANG')
                       AND UPPER (meaning) =
                           LTRIM (RTRIM (ucc_inquiry_gtmp_rec.quality_code));
            EXCEPTION
                WHEN OTHERS
                THEN
                    v_status_id   := NULL;
            END;



            sn_rec.serial_number           := ucc_inquiry_gtmp_rec.package_code_value;
            sn_rec.product_qr_code         :=
                NVL (ucc_inquiry_gtmp_rec.product_code_value, 'UNKNOWN');
            sn_rec.lpn_id                  := lpn_to_lpnid (p_lpn_number);
            sn_rec.license_plate_number    := p_lpn_number;
            sn_rec.inventory_item_id       := p_inventory_item_id;
            sn_rec.organization_id         := p_organization_id;
            sn_rec.status_id               := v_status_id;
            sn_rec.source_code             := 'INITIAL_ENTRY';
            sn_rec.source_code_reference   := p_source_reference_id;

            -- Call the update_serial_temp API to insert/update the xxdo_serial_temp table
            apps.xxdo_serialization.update_serial_temp (sn_rec, l_debug_level, x_return_status
                                                        , x_error_message);

            fnd_file.put_line (
                fnd_file.LOG,
                   ucc_inquiry_gtmp_rec.package_code_value
                || '-'
                || x_return_status
                || '-'
                || x_error_message);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := 'E';
            x_error_message   :=
                'Unknown error while inserting data into xxdo_serial_temp table, procedure XXDO_WMS_QR_PROCESSING_API.insert_xxdo_serial_temp_prc ';
    END insert_xxdo_serial_temp_prc;

    PROCEDURE xxdo_populate_serial_temp_prc (x_return_status OUT NOCOPY VARCHAR2, x_error_message OUT NOCOPY VARCHAR2, p_organization_id IN NUMBER
                                             , p_include_lpn_context_4_5 IN VARCHAR2 DEFAULT 'Y', p_trans_start_date IN VARCHAR2, p_trans_end_date IN VARCHAR2)
    IS
        CURSOR eligible_lpn_cur (p_orgn_id IN NUMBER)
        IS
            SELECT DISTINCT wlpn.license_plate_number lpn, mmt.organization_id, mmt.inventory_item_id,
                            mmt.transaction_id
              FROM apps.mtl_material_transactions mmt, apps.wms_license_plate_numbers wlpn
             WHERE     mmt.transaction_type_id = 18
                   AND mmt.transaction_action_id = 27
                   AND mmt.transaction_source_type_id = 1
                   AND mmt.lpn_id = wlpn.lpn_id
                   AND mmt.organization_id = p_orgn_id
                   AND mmt.transaction_date BETWEEN fnd_date.canonical_to_date (
                                                        p_trans_start_date)
                                                AND fnd_date.canonical_to_date (
                                                        p_trans_end_date)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxdo_serial_temp xst
                             WHERE     xst.organization_id =
                                       mmt.organization_id
                                   AND xst.lpn_id = mmt.lpn_id);

        CURSOR eligible_lpn_context_cur (p_orgn_id IN NUMBER)
        IS
            SELECT DISTINCT wlpn.license_plate_number lpn, mmt.organization_id, mmt.inventory_item_id,
                            mmt.transaction_id
              FROM apps.mtl_material_transactions mmt, apps.wms_license_plate_numbers wlpn
             WHERE     mmt.transaction_type_id = 18
                   AND mmt.transaction_action_id = 27
                   AND mmt.transaction_source_type_id = 1
                   AND mmt.lpn_id = wlpn.lpn_id
                   AND wlpn.lpn_context NOT IN ('4', '5')
                   AND mmt.organization_id = p_orgn_id
                   AND mmt.transaction_date BETWEEN fnd_date.canonical_to_date (
                                                        p_trans_start_date)
                                                AND fnd_date.canonical_to_date (
                                                        p_trans_end_date)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxdo_serial_temp xst
                             WHERE     xst.organization_id =
                                       mmt.organization_id
                                   AND xst.lpn_id = mmt.lpn_id);


        TYPE eligible_lpn_rows IS TABLE OF eligible_lpn_cur%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_table_eligible_lpn_rows   eligible_lpn_rows;

        l_return_status             VARCHAR2 (1);
        l_error_message             VARCHAR2 (5000);
        v_gtmp_count                NUMBER := 0;
        n_carton                    NUMBER := 0;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Begin of procedure xxdo_populate_serial_temp_prc');

        IF p_include_lpn_context_4_5 = 'Y'
        THEN
            OPEN eligible_lpn_cur (p_organization_id);

            fnd_file.put_line (fnd_file.LOG,
                               'After opening the cursor eligible_lpn_cur');
        ELSE
            OPEN eligible_lpn_context_cur (p_organization_id);

            fnd_file.put_line (
                fnd_file.LOG,
                'After opening the cursor eligible_lpn_context_cur');
        END IF;

        LOOP
            IF p_include_lpn_context_4_5 = 'Y'
            THEN
                FETCH eligible_lpn_cur
                    BULK COLLECT INTO l_table_eligible_lpn_rows
                    LIMIT 100;
            ELSE
                FETCH eligible_lpn_context_cur
                    BULK COLLECT INTO l_table_eligible_lpn_rows
                    LIMIT 100;
            END IF;

            EXIT WHEN l_table_eligible_lpn_rows.COUNT = 0;

            FOR indx IN 1 .. l_table_eligible_lpn_rows.COUNT
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before call to  xxdo_wms_qr_processing_api.qr_api_main'
                    || '-'
                    || l_table_eligible_lpn_rows (indx).lpn);
                xxdo_wms_qr_processing_api.qr_api_main (
                    x_return_status   => l_return_status,
                    x_error_message   => l_error_message,
                    p_qr_input_str    => l_table_eligible_lpn_rows (indx).lpn,
                    p_query_type      => 'UCC');

                SELECT COUNT (*)
                  INTO v_gtmp_count
                  FROM XXDO.XXDO_UCC_INQUIRY_GTMP
                 WHERE package_code_value IS NOT NULL;

                --Call this procedure to insert records into the xxdo_serial_temp table only if records are found in the global temp table
                IF v_gtmp_count > 0
                THEN
                    insert_xxdo_serial_temp_prc (
                        x_return_status         => l_return_status,
                        x_error_message         => l_error_message,
                        p_lpn_number            =>
                            l_table_eligible_lpn_rows (indx).lpn,
                        p_inventory_item_id     =>
                            l_table_eligible_lpn_rows (indx).inventory_item_id,
                        p_source_reference_id   =>
                            l_table_eligible_lpn_rows (indx).transaction_id,
                        p_organization_id       => p_organization_id);
                    COMMIT; -- THE COMMIT WILL RE-INITIALIZE THE GLOBAL TEMP TABLE FOR NEXT FETCH FROM QR DATABASE
                END IF;

                n_carton   := n_carton + 1;
            END LOOP;
        END LOOP;

        IF p_include_lpn_context_4_5 = 'Y'
        THEN
            CLOSE eligible_lpn_cur;
        ELSE
            CLOSE eligible_lpn_context_cur;
        END IF;

        x_return_status   := 'S';
        x_error_message   := '';

        fnd_file.put_line (
            fnd_file.LOG,
               'TOTAL NUMBER OF CARTONS/LPNS PROCESSED IN THIS RUN : '
            || n_carton);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_return_status   := 'S';
            x_return_status   :=
                'Unknown exception occured in the call to the procedure procedure xxdo_wms_qr_processing_api.xxdo_populate_serial_temp_prc';
    END xxdo_populate_serial_temp_prc;

    PROCEDURE xxdo_populate_serial_temp_prc (
        errbuf                         OUT NOCOPY VARCHAR2,
        retcode                        OUT NOCOPY NUMBER,
        p_organization_id           IN            NUMBER,
        p_include_lpn_context_4_5   IN            VARCHAR2 DEFAULT 'Y',
        p_trans_start_date          IN            VARCHAR2,
        p_trans_end_date            IN            VARCHAR2,
        p_conc_program_flag         IN            VARCHAR2 DEFAULT 'Y')
    IS
        v_return_status   VARCHAR2 (1);
        v_error_message   VARCHAR2 (5000);
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Begin of procedure xxdo_populate_serial_temp_prc');
        fnd_file.put_line (fnd_file.LOG,
                           'Organization ID is :' || p_organization_id);

        xxdo_wms_qr_processing_api.xxdo_populate_serial_temp_prc (
            x_return_status             => v_return_status,
            x_error_message             => v_error_message,
            p_organization_id           => p_organization_id,
            p_include_lpn_context_4_5   => p_include_lpn_context_4_5,
            p_trans_start_date          => p_trans_start_date,
            p_trans_end_date            => p_trans_end_date);


        fnd_file.put_line (
            fnd_file.LOG,
               'After call to procedure xxdo_populate_serial_temp_prc'
            || v_return_status
            || '-'
            || v_error_message);

        IF v_return_status = 'E'
        THEN
            errbuf    := v_error_message;
            retcode   := 2;
            ROLLBACK;
            RETURN;
        ELSIF v_return_status = 'S'
        THEN
            errbuf    := 'Successfully populated the xxdo_serial_temp table';
            retcode   := 0;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    :=
                'Unknown exception occured in the call to the procedure procedure xxdo_wms_qr_processing_api.xxdo_populate_serial_temp_prc';
            retcode   := 2;
            ROLLBACK;
            RETURN;
    END xxdo_populate_serial_temp_prc;
END XXDO_WMS_QR_PROCESSING_API;
/
