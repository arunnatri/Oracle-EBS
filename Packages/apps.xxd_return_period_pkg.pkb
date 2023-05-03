--
-- XXD_RETURN_PERIOD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxd_return_period_pkg
AS
    FUNCTION XXD_RETURN_QUARTER_func (pv_period_name VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_quarter_period   VARCHAR2 (20);

        cutoffdt            DATE;

        ln_mon_num          NUMBER (2);
    BEGIN
        SELECT TO_NUMBER (TO_CHAR (TO_DATE (pv_period_name, 'MON-YY'), 'MM'))
          INTO ln_mon_num
          FROM DUAL;


        IF ln_mon_num IN (1, 2, 3)
        THEN
            lv_quarter_period   :=
                   'JAN-'
                || (TO_CHAR (TO_DATE (pv_period_name, 'MON-YY'), 'YY'));
        ELSIF ln_mon_num IN (4, 5, 6)
        THEN
            lv_quarter_period   :=
                   'APR-'
                || (TO_CHAR (TO_DATE (pv_period_name, 'MON-YY'), 'YY'));
        ELSIF ln_mon_num IN (7, 8, 9)
        THEN
            lv_quarter_period   :=
                   'JUL-'
                || (TO_CHAR (TO_DATE (pv_period_name, 'MON-YY'), 'YY'));
        ELSIF ln_mon_num IN (10, 11, 12)
        THEN
            lv_quarter_period   :=
                   'OCT-'
                || (TO_CHAR (TO_DATE (pv_period_name, 'MON-YY'), 'YY'));
        END IF;

        RETURN lv_quarter_period;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception while extracting QTD Period');
            RETURN NULL;
    END;


    FUNCTION XXD_RETURN_first_period_func (pv_period_name VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_first_period   VARCHAR2 (20);
    BEGIN
        SELECT period_name
          INTO lv_first_period
          FROM gl_periods
         WHERE     period_year IN
                       (SELECT period_year
                          FROM gl_periods
                         WHERE     period_name = pv_period_name
                               AND period_set_name LIKE 'DO_FY_CALENDAR')
               AND period_num = 1
               AND period_set_name LIKE 'DO_FY_CALENDAR';


        RETURN lv_first_period;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'OTHERS Exception while extracting YTD Period for period name '
                || pv_period_name
                || ' and error is '
                || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION RETURN_QUARTER_DATE_func (pv_period_name VARCHAR2)
        RETURN DATE
    IS
        lv_quarter_period      VARCHAR2 (20);

        lv_quarter_period_dt   DATE;

        ln_mon_num             NUMBER (2);
    BEGIN
        SELECT TO_NUMBER (TO_CHAR (TO_DATE (pv_period_name, 'MON-YY'), 'MM'))
          INTO ln_mon_num
          FROM DUAL;


        IF ln_mon_num IN (1, 2, 3)
        THEN
            lv_quarter_period   :=
                   'JAN-'
                || (TO_CHAR (TO_DATE (pv_period_name, 'MON-YY'), 'YY'));
        ELSIF ln_mon_num IN (4, 5, 6)
        --after march it should return the previous year date
        THEN
            lv_quarter_period   :=
                     'APR-'
                  || TO_NUMBER (
                         (TO_CHAR (TO_DATE (pv_period_name, 'MON-YY'), 'YY')))
                - 1;
        ELSIF ln_mon_num IN (7, 8, 9)
        THEN
            lv_quarter_period   :=
                     'JUL-'
                  || TO_NUMBER (
                         (TO_CHAR (TO_DATE (pv_period_name, 'MON-YY'), 'YY')))
                - 1;
        ELSIF ln_mon_num IN (10, 11, 12)
        THEN
            lv_quarter_period   :=
                     'OCT-'
                  || TO_NUMBER (
                         (TO_CHAR (TO_DATE (pv_period_name, 'MON-YY'), 'YY')))
                - 1;
        END IF;

        DBMS_OUTPUT.put_line ('FIRST LINE' || lv_quarter_period);

        lv_quarter_period_dt   := TO_DATE (lv_quarter_period, 'MON-YY');

        DBMS_OUTPUT.put_line ('SECOND LINE' || lv_quarter_period_dt);
        RETURN lv_quarter_period_dt;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception while extracting QTD Period' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'OTHERS Exception while extracting QTD Period' || SQLERRM);
            RETURN NULL;
    END;

    FUNCTION RETURN_first_period_date_func (pv_period_name VARCHAR2)
        RETURN DATE
    IS
        lv_first_period      VARCHAR2 (20);
        lv_first_period_dt   DATE;
        ln_mon_num           NUMBER (2);
    BEGIN
        SELECT TO_NUMBER (TO_CHAR (TO_DATE (pv_period_name, 'MON-YY'), 'MM'))
          INTO ln_mon_num
          FROM DUAL;

        SELECT period_name
          INTO lv_first_period
          FROM gl_periods
         WHERE     period_year IN
                       (SELECT period_year
                          FROM gl_periods
                         WHERE     period_name = pv_period_name
                               AND period_set_name LIKE 'DO_FY_CALENDAR')
               AND period_num = 1
               AND period_set_name LIKE 'DO_FY_CALENDAR';

        IF ln_mon_num IN (1, 2, 3)
        THEN
            lv_first_period_dt   := TO_DATE (lv_first_period, 'MON-YY');
        ELSIF ln_mon_num IN (4, 5, 6,
                             7, 8, 9,
                             10, 11, 12)
        THEN
            --after march it should return the previous year date
            lv_first_period_dt   :=
                ADD_MONTHS (TO_DATE (lv_first_period, 'MON-YY'), -12);
        END IF;

        RETURN lv_first_period_dt;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'OTHERS Exception while extracting YTD Period');
            RETURN NULL;
    END;


    FUNCTION XXD_RETURN_PREV_PRD_FUNC (pv_period_name VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_prev_period   VARCHAR2 (20);
    BEGIN
        SELECT TO_CHAR (ADD_MONTHS (TO_DATE (pv_period_name, 'MON-RRRR'), -1), 'MON-YY')
          INTO lv_prev_period
          FROM DUAL;



        RETURN lv_prev_period;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'OTHERS Exception while extracting Previous Period'
                || SQLERRM);
            RETURN NULL;
    END;
END;
/
