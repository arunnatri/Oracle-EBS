--
-- XXDOFA_ASSET_TRANSFER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDOFA_ASSET_TRANSFER_PKG
AS
    /******************************************************************************
       NAME:       XXDOFA_ASSET_TRANSFER_PKG
       PURPOSE:

       REVISIONS:
       Ver        Date        Author                    Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        15/09/2014    BT TechnologyTeam     Created
    ******************************************************************************/

    FUNCTION GET_ADJ_TABLE (p_sob_id IN NUMBER)
        RETURN BOOLEAN
    IS
        l_mrcsobtype      VARCHAR2 (1);
        l_currency_code   VARCHAR2 (3);
    BEGIN
        BEGIN
            SELECT mrc_sob_type_code, currency_code
              INTO l_mrcsobtype, l_currency_code
              FROM gl_sets_of_books
             WHERE set_of_books_id = p_sob_id;

            g_currency   := l_currency_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_mrcsobtype   := 'P';
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Error while fetching set of books id '
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;


        IF l_mrcsobtype = 'R'
        THEN
            g_table   := 'FA_MC_ADJUSTMENTS';

            g_where   :=
                   ' CADJ.set_of_books_id ='
                || p_sob_id
                || ' And RADJ.set_of_books_id ='
                || p_sob_id;
        ELSE
            g_table   := 'FA_ADJUSTMENTS';

            g_where   := ' 1=1';
        END IF;



        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
               'g_table - '
            || g_table
            || ' g_where - '
            || g_where
            || ' g_currency - '
            || g_currency);


        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            g_table   := 'FA_ADJUSTMENTS';

            g_where   := ' ';


            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Error while fetching fa tables '
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
            RETURN (FALSE);
    END GET_ADJ_TABLE;
END XXDOFA_ASSET_TRANSFER_PKG;
/
