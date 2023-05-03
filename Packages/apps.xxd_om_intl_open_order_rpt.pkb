--
-- XXD_OM_INTL_OPEN_ORDER_RPT  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_OM_INTL_OPEN_ORDER_RPT"
AS
    /****************************************************************************************
    * Package      : XXD_OM_INTL_OPEN_ORDER_RPT
    * Design       : This package will be used for Deckers Intl Open Orders Report
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name             Comments
    -- ======================================================================================
    -- 29-Aug-2022  1.0        Ramesh BR        Initial Version
    ******************************************************************************************/

    FUNCTION MAIN_LOAD
        RETURN BOOLEAN
    IS
    BEGIN
        IF     (P_FROM_SHIP_DATE IS NOT NULL AND P_TO_SHIP_DATE IS NOT NULL)
           AND (P_FROM_ORDER_DATE IS NOT NULL AND P_TO_ORDER_DATE IS NOT NULL)
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'Please enter only one date range either Shipment Date or Order Date');

            RETURN FALSE;
        END IF;

        IF P_FROM_SHIP_DATE IS NOT NULL AND P_TO_SHIP_DATE IS NOT NULL
        THEN
            where_clause   :=
                'AND (   (    oola.open_flag = ''N''
                            AND oola.actual_shipment_date BETWEEN NVL (
                                                                     fnd_conc_date.string_to_date (
                                                                        :p_from_ship_date),
                                                                     oola.actual_shipment_date)
                                                              AND NVL (
                                                                     fnd_conc_date.string_to_date (
                                                                        :p_to_ship_date),
                                                                     oola.actual_shipment_date))
                        OR (oola.open_flag = ''Y'' AND ooha.open_flag = ''Y''))';
        END IF;

        IF P_FROM_ORDER_DATE IS NOT NULL AND P_TO_ORDER_DATE IS NOT NULL
        THEN
            where_clause   :=
                'AND TRUNC(ooha.ordered_date) BETWEEN TO_DATE (:P_FROM_ORDER_DATE, ''YYYY/MM/DD HH24:MI:SS'')
						                                   AND TO_DATE (:P_TO_ORDER_DATE, ''YYYY/MM/DD HH24:MI:SS'')';
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in WHEN OTHERS of main ' || SQLERRM);

            RETURN FALSE;
    END MAIN_LOAD;
END XXD_OM_INTL_OPEN_ORDER_RPT;
/
