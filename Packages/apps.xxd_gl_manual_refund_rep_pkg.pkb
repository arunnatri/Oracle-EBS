--
-- XXD_GL_MANUAL_REFUND_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_MANUAL_REFUND_REP_PKG"
AS
    /******************************************************************************
     NAME: XXDO.XXDOAR014_REP_PKG
     REP NAME:Commerce Receipts Report Details - Deckers

     REVISIONS:
     Ver       Date       Author          Description
     --------- ---------- --------------- ------------------------------------
     1.0       01/14/19   Madhav Dhurjaty Initial Version - CCR0007732
    ******************************************************************************/
    FUNCTION before_report
        RETURN BOOLEAN
    IS
    BEGIN
        apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'Inside before_report ');
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Error in before_report -' || SQLERRM);
            RETURN FALSE;
    END before_report;

    --
    FUNCTION directory_path
        RETURN VARCHAR2
    IS
    BEGIN
        /* param p_path now has the complete path. just return the same
        IF p_file_path IS NOT NULL
         THEN
            BEGIN
               SELECT directory_path
                 INTO p_path
                 FROM dba_directories
                WHERE directory_name = p_file_path;
            EXCEPTION
               WHEN OTHERS THEN
                  apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'Unable to get the file path for directory - '
                                        ||p_file_path);
            END;
         END IF;
         */
        RETURN p_path;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Error in directory_path -' || SQLERRM);
    END directory_path;

    --
    FUNCTION file_name
        RETURN VARCHAR2
    IS
    BEGIN
        IF p_path IS NOT NULL
        THEN
            P_FILE_NAME   :=
                'ManRef_' || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
        END IF;

        RETURN P_FILE_NAME;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Error in file_name -' || SQLERRM);
    END file_name;

    --
    FUNCTION after_report
        RETURN BOOLEAN
    IS
        l_req_id   NUMBER;
    BEGIN
        --RETURN FALSE;
        apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG, 'inside after_report');

        IF NVL (P_SEND_TO_BLACKLINE, 'N') = 'Y'
        THEN
            IF P_PATH IS NOT NULL
            THEN
                l_req_id   :=
                    FND_REQUEST.SUBMIT_REQUEST (
                        application   => 'XDO',
                        program       => 'XDOBURSTREP',
                        description   =>
                               'Bursting - Placing '
                            || P_FILE_NAME
                            || ' under '
                            || P_PATH,
                        start_time    => SYSDATE,
                        sub_request   => FALSE,
                        argument1     => 'Y',
                        argument2     => APPS.FND_GLOBAL.CONC_REQUEST_ID,
                        argument3     => 'Y');

                IF NVL (l_req_id, 0) = 0
                THEN
                    apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                            'Bursting Failed');
                END IF;
            END IF;
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Error in after_report -' || SQLERRM);
            RETURN FALSE;
    END after_report;
END XXD_GL_MANUAL_REFUND_REP_PKG;
/
