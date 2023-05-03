--
-- XXDOGL005_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDOGL005_PKG
AS
    PROCEDURE MAIN (PV_ERRBUF             OUT VARCHAR2,
                    PV_RETCODE            OUT VARCHAR2,
                    PV_RUNDATE         IN     VARCHAR2,
                    PV_REPROCESSFLAG   IN     VARCHAR2,
                    PV_REPROCESSDATE   IN     VARCHAR2)
    IS
        lv_wsdl_ip       VARCHAR2 (25);
        lv_wsdl_url      VARCHAR2 (4000);
        lv_namespace     VARCHAR2 (4000);
        lv_service       VARCHAR2 (4000);
        lv_port          VARCHAR2 (4000);
        lv_operation     VARCHAR2 (4000);
        lv_targetname    VARCHAR2 (4000);

        lx_xmltype_in    SYS.XMLTYPE;
        lx_xmltype_out   SYS.XMLTYPE;
        lc_return        CLOB;

        LV_ERRMSG        VARCHAR2 (4000);
        LV_RUN_DATE1     DATE;
        LV_REPUB_DATE    DATE;



        CURSOR CUR_gl_rates (LV_RUN_DATE VARCHAR2)
        IS
            SELECT from_currency,
                   to_currency,
                      TO_CHAR (conversion_date, 'RRRR-MM-DD')
                   || 'T'
                   || TO_CHAR (Conversion_date, 'HH24:MI:SS')
                       CONVERSION_DATE,
                   conversion_date
                       conversion_date1,
                   conversion_rate,
                   conversion_type
                       user_conversion_type,
                   XMLELEMENT (
                       "v1:CurrRateDesc",
                       XMLELEMENT ("v1:from_currency", from_currency),
                       XMLELEMENT ("v1:to_currency", to_currency),
                       XMLELEMENT (
                           "v1:conversion_date",
                              TO_CHAR (conversion_date, 'YYYY-MM-DD')
                           || 'T'
                           || TO_CHAR (conversion_date, 'HH24:MI:SS')),
                       XMLELEMENT ("v1:conversion_rate",
                                   ROUND (conversion_rate, 5)),
                       XMLELEMENT ("v1:user_conversion_type",
                                   conversion_type))
                       CURRATE
              FROM gl_daily_rates
             WHERE --to_currency in ('CAD','CNY','EUR','GBP','HKD','JPY','MOP','VND')
                                                                         --and
                       conversion_type = 'Corporate'
                   AND NVL (attribute15, 'N') = 'N'
                   AND from_currency = 'USD'
                   AND TRUNC (CONVERSION_DATE) =
                       TRUNC (NVL (TO_DATE (LV_RUN_DATE), SYSDATE));



        CURSOR CUR_GLRATEPUBLISH IS
            SELECT *
              FROM XXDO.XXDOGL005_INT
             WHERE STATUS_FLAG = 'N';


        CURSOR CUR_GLREPUBLISH (LV_REPUBDATE VARCHAR2)
        IS
            SELECT *
              FROM XXDO.XXDOGL005_INT
             WHERE TRUNC (TRANSMISSION_DATE) =
                   TRUNC (TO_DATE (LV_REPUBDATE), 'MM');
    BEGIN
        /* Setting the Retail PROD/DEV Environment based on Oracle Prod / Dev Instances */

        BEGIN
            SELECT DECODE (APPLICATIONS_SYSTEM_NAME, 'PROD', APPS.FND_PROFILE.VALUE ('XXDO: RETAIL PROD'), APPS.FND_PROFILE.VALUE ('XXDO: RETAIL TEST')) FILE_SERVER_NAME
              INTO lv_wsdl_ip
              FROM APPS.FND_PRODUCT_GROUPS;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Unable to fetch the File server name');
                pv_retcode   := 2;
        END;


        LV_RUN_DATE1    := TO_DATE (PV_RUNDATE, 'RRRR/MM/DD HH24:MI:SS');
        LV_REPUB_DATE   :=
            TO_DATE (PV_REPROCESSDATE, 'RRRR/MM/DD HH24:MI:SS');


        /* Initializing the Curr Rates web service variables */

        lv_wsdl_url     :=
               'http://'
            || lv_wsdl_ip
            || '/CurRatePublishingBean/CurRatePublishingService?WSDL';
        lv_namespace    :=
            'http://www.oracle.com/retail/igs/integration/services/CurRatePublishingService/v1';
        lv_service      := 'CurRatePublishingService';
        lv_port         := 'CurRatePublishingPort';
        lv_operation    := 'publishCurrRateCreateUsingCurrRateDesc';
        lv_targetname   :=
               'http://'
            || lv_wsdl_ip
            || '/CurRatePublishingBean/CurRatePublishingService';


        IF PV_REPROCESSFLAG = 'Y'
        THEN
            FOR REC_GLRATESREPUB IN CUR_GLREPUBLISH (LV_REPUB_DATE)
            LOOP
                FOR REC_GLRATES IN CUR_GL_RATES (LV_REPUB_DATE)
                LOOP
                    UPDATE XXDO.XXDOGL005_INT
                       SET XDATA   = xmltype.getClobVal (REC_GLRATES.CURRATE)
                     WHERE SLNO = REC_GLRATESREPUB.SLNO;

                    COMMIT;
                END LOOP;

                lx_xmltype_in   :=
                    SYS.XMLTYPE (
                           '<publishCurrRateCreateUsingCurrRateDesc
xmlns="http://www.oracle.com/retail/igs/integration/services/CurRatePublishingService/v1"
					     xmlns:v1="http://www.oracle.com/retail/integration/base/bo/CurrRateDesc/v1"
					     xmlns:v11="http://www.oracle.com/retail/integration/custom/bo/ExtOfCurrRateDesc/v1"
					     xmlns:v12="http://www.oracle.com/retail/integration/base/bo/LocOfCurrRateDesc/v1"
				             xmlns:v13="http://www.oracle.com/retail/integration/localization/bo/InCurrRateDesc/v1"
                                             xmlns:v14="http://www.oracle.com/retail/integration/custom/bo/EOfInCurrRateDesc/v1"
                                             xmlns:v15="http://www.oracle.com/retail/integration/localization/bo/BrCurrRateDesc/v1"
                                             xmlns:v16="http://www.oracle.com/retail/integration/custom/bo/EOfBrCurrRateDesc/v1">
						'
                        || REC_GLRATESREPUB.XDATA
                        || '</publishCurrRateCreateUsingCurrRateDesc>');

                /* Calling the webservice here */

                BEGIN
                    lx_xmltype_out   :=
                        XXDO_INVOKE_WEBSERVICE_F (lv_wsdl_url, lv_namespace, lv_targetname, lv_service, lv_port, lv_operation
                                                  , lx_xmltype_in);

                    IF lx_xmltype_out IS NOT NULL
                    THEN
                        FND_FILE.PUT_LINE (
                            FND_FILE.OUTPUT,
                            'Response is stored in the staging table  ');

                        lc_return   := xmltype.getClobVal (lx_xmltype_out);

                        UPDATE XXDO.XXDOGL005_INT
                           SET RETVAL = LC_RETURN, PROCESSED_FLAG = 'Y', STATUS_FLAG = 'P',
                               TRANSMISSION_DATE = SYSDATE
                         WHERE SLNO = REC_GLRATESREPUB.SLNO;
                    ELSE
                        FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                                           'Response is NULL  ');

                        lc_return   := NULL;

                        UPDATE XXDO.XXDOGL005_INT
                           SET RETVAL = LC_RETURN, STATUS_FLAG = 'VE', TRANSMISSION_DATE = SYSDATE
                         WHERE SLNO = REC_GLRATESREPUB.SLNO;
                    END IF;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        LV_ERRMSG   := SQLERRM;

                        /* Updating the existing record to validation error and storing the error code */

                        UPDATE XXDO.XXDOGL005_INT
                           SET STATUS_FLAG = 'VE', ERRORCODE = LV_ERRMSG
                         WHERE SLNO = REC_GLRATESREPUB.SLNO;

                        COMMIT;

                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'PROBLEM IN SENDING THE MESSAGE DETAILS STORED IN THE ERRORCODE OF THE STAGING TABLE   '
                            || SQLERRM);
                END;                        /* End calling the webservice   */
            END LOOP;                                     /* For RE Publish */
        ELSE
            FOR REC_GLRATES IN CUR_GL_RATES (LV_RUN_DATE1)
            LOOP
                IF (REC_GLRATES.FROM_CURRENCY IS NULL OR REC_GLRATES.TO_CURRENCY IS NULL OR REC_GLRATES.CONVERSION_DATE IS NULL OR REC_GLRATES.CONVERSION_RATE IS NULL OR REC_GLRATES.USER_CONVERSION_TYPE IS NULL)
                THEN
                    BEGIN
                        INSERT INTO XXDO.XXDOGL005_INT (SLNO,
                                                        FROM_CURRENCY,
                                                        TO_CURRENCY,
                                                        CONVERSION_DATE,
                                                        CONVERSION_RATE,
                                                        USER_CONVERSION_TYPE,
                                                        STATUS_FLAG,
                                                        TRANSMISSION_DATE,
                                                        ERRORCODE)
                                 VALUES (
                                            XXDO.XXDOGL005_INT_S.NEXTVAL,
                                            REC_GLRATES.FROM_CURRENCY,
                                            REC_GLRATES.TO_CURRENCY,
                                            REC_GLRATES.CONVERSION_DATE,
                                            REC_GLRATES.CONVERSION_RATE,
                                            REC_GLRATES.USER_CONVERSION_TYPE,
                                            'VE',
                                            SYSDATE,
                                            'Error as one of the Mandatory column is NULL and cannot transmit the data ');

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            FND_FILE.PUT_LINE (
                                FND_FILE.LOG,
                                'Exception occured while validating the gl curr rate data ');
                    END;

                    FND_FILE.PUT_LINE (
                        FND_FILE.OUTPUT,
                        'Validation error occured one of the mandatory value is Null');
                ELSE
                    BEGIN
                        --fnd_file.put_line(Fnd_File.log,REC_GLRATES.CONVERSION_DATE);

                        INSERT INTO XXDO.XXDOGL005_INT (SLNO, FROM_CURRENCY, TO_CURRENCY, CONVERSION_DATE, CONVERSION_RATE, USER_CONVERSION_TYPE
                                                        , XDATA)
                                 VALUES (
                                            XXDO.XXDOGL005_INT_S.NEXTVAL,
                                            REC_GLRATES.FROM_CURRENCY,
                                            REC_GLRATES.TO_CURRENCY,
                                            REC_GLRATES.CONVERSION_DATE,
                                            REC_GLRATES.CONVERSION_RATE,
                                            REC_GLRATES.USER_CONVERSION_TYPE,
                                            xmltype.getClobVal (
                                                REC_GLRATES.CURRATE));

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            FND_FILE.PUT_LINE (
                                FND_FILE.LOG,
                                'Exception occured while loading  the gl curr rate data into the staging table');
                    END;
                END IF;
            END LOOP;


            FOR J IN CUR_GLRATEPUBLISH
            LOOP
                lx_xmltype_in   :=
                    SYS.XMLTYPE (
                           '<publishCurrRateCreateUsingCurrRateDesc
xmlns="http://www.oracle.com/retail/igs/integration/services/CurRatePublishingService/v1"
					     xmlns:v1="http://www.oracle.com/retail/integration/base/bo/CurrRateDesc/v1"
					     xmlns:v11="http://www.oracle.com/retail/integration/custom/bo/ExtOfCurrRateDesc/v1"
					     xmlns:v12="http://www.oracle.com/retail/integration/base/bo/LocOfCurrRateDesc/v1"
				             xmlns:v13="http://www.oracle.com/retail/integration/localization/bo/InCurrRateDesc/v1"
                                             xmlns:v14="http://www.oracle.com/retail/integration/custom/bo/EOfInCurrRateDesc/v1"
                                             xmlns:v15="http://www.oracle.com/retail/integration/localization/bo/BrCurrRateDesc/v1"
                                             xmlns:v16="http://www.oracle.com/retail/integration/custom/bo/EOfBrCurrRateDesc/v1">
						'
                        || J.XDATA
                        || '</publishCurrRateCreateUsingCurrRateDesc>');

                /* Calling the webservice here */

                BEGIN
                    lx_xmltype_out   :=
                        XXDO_INVOKE_WEBSERVICE_F (lv_wsdl_url, lv_namespace, lv_targetname, lv_service, lv_port, lv_operation
                                                  , lx_xmltype_in);

                    IF lx_xmltype_out IS NOT NULL
                    THEN
                        FND_FILE.PUT_LINE (
                            FND_FILE.OUTPUT,
                            'Response is stored in the staging table  ');

                        lc_return   := xmltype.getClobVal (lx_xmltype_out);

                        UPDATE XXDO.XXDOGL005_INT
                           SET RETVAL = LC_RETURN, PROCESSED_FLAG = 'Y', STATUS_FLAG = 'P',
                               TRANSMISSION_DATE = SYSDATE
                         WHERE SLNO = J.SLNO;
                    ELSE
                        FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                                           'Response is NULL  ');

                        lc_return   := NULL;

                        UPDATE XXDO.XXDOGL005_INT
                           SET RETVAL = LC_RETURN, STATUS_FLAG = 'VE', TRANSMISSION_DATE = SYSDATE
                         WHERE SLNO = J.SLNO;
                    END IF;

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        LV_ERRMSG   := SQLERRM;

                        /* Updating the existing record to validation error and storing the error code */

                        UPDATE XXDO.XXDOGL005_INT
                           SET STATUS_FLAG = 'VE', ERRORCODE = LV_ERRMSG
                         WHERE SLNO = J.SLNO;

                        COMMIT;

                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               'PROBLEM IN SENDING THE MESSAGE DETAILS STORED IN THE ERRORCODE OF THE STAGING TABLE   '
                            || SQLERRM);
                END;                        /* End calling the webservice   */
            END LOOP;                                    /* For Publish Loc */
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Exception Occured in Curr Rate Procedure and it is    '
                || SQLERRM);
    END;
END XXDOGL005_PKG;
/
