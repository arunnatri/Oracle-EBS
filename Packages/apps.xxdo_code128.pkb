--
-- XXDO_CODE128  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXDO_CODE128
AS
    TYPE code128_byte IS RECORD
    (
        vlue         NUMBER,
        bs_weight    VARCHAR2 (8),
        c128a        VARCHAR2 (20),
        c128b        VARCHAR2 (20),
        c128c        VARCHAR2 (20),
        chars        VARCHAR2 (4)
    );

    TYPE code128_t IS TABLE OF code128_byte;

    code_table   code128_t := code128_t ();

    FUNCTION code_direct (vlue NUMBER)
        RETURN VARCHAR2
    IS
    BEGIN
        FOR i IN 1 .. code_table.COUNT
        LOOP
            IF code_table (i).vlue = vlue
            THEN
                RETURN code_table (i).chars;
            END IF;
        END LOOP;

        RETURN NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION code128_direct (dta VARCHAR2)
        RETURN VARCHAR2
    IS
    BEGIN
        FOR i IN 1 .. code_table.COUNT
        LOOP
            IF code_table (i).c128c = dta
            THEN
                RETURN code_table (i).chars;
            END IF;
        END LOOP;

        RETURN NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION code128_direct_v (dta VARCHAR2)
        RETURN NUMBER
    IS
    BEGIN
        FOR i IN 1 .. code_table.COUNT
        LOOP
            IF code_table (i).c128c = dta
            THEN
                RETURN code_table (i).vlue;
            END IF;
        END LOOP;

        RETURN NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION C128C_to_num (dta VARCHAR2)
        RETURN NUMBER
    IS
    BEGIN
        FOR i IN 1 .. code_table.COUNT
        LOOP
            IF code_table (i).chars = dta
            THEN
                RETURN code_table (i).vlue;
            END IF;
        END LOOP;

        RETURN NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;


    FUNCTION code128c (data_to_encode VARCHAR2)
        RETURN VARCHAR2
    IS
        encoded_data   VARCHAR2 (4000) := NULL;
        checkdig       NUMBER := 105;
        k              NUMBER := 1;
        l              NUMBER := 0;
    BEGIN
        encoded_data   := code_direct (105);

        WHILE k < LENGTH (data_to_encode)
        LOOP
            l   := l + 1;

            IF SUBSTR (data_to_encode, k, 1) = '~'
            THEN
                encoded_data   := encoded_data || code_direct (102);
                checkdig       := checkdig + l * 102;
                k              := k + 1;
            ELSE
                encoded_data   :=
                       encoded_data
                    || code128_direct (
                           RPAD (SUBSTR (data_to_encode, k, 2), 2, '0'));
                checkdig   :=
                      checkdig
                    +   l
                      * code128_direct_v (
                            RPAD (SUBSTR (data_to_encode, k, 2), 2, '0'));
                k   := k + 2;
            END IF;
        END LOOP;

        encoded_data   :=
               encoded_data
            || code_direct (MOD (checkdig, 103))
            || code_direct (106);

        RETURN encoded_data;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;
BEGIN
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 0;
    code_table (code_table.COUNT).bs_weight   := '212222';
    code_table (code_table.COUNT).c128a       := ' ';
    code_table (code_table.COUNT).c128b       := ' ';
    code_table (code_table.COUNT).c128c       := '00';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 1;
    code_table (code_table.COUNT).bs_weight   := '222122';
    code_table (code_table.COUNT).c128a       := '?!';
    code_table (code_table.COUNT).c128b       := '?!';
    code_table (code_table.COUNT).c128c       := '01';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 2;
    code_table (code_table.COUNT).bs_weight   := '222221';
    code_table (code_table.COUNT).c128a       := '"';
    code_table (code_table.COUNT).c128b       := '"';
    code_table (code_table.COUNT).c128c       := '02';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 3;
    code_table (code_table.COUNT).bs_weight   := '121223';
    code_table (code_table.COUNT).c128a       := '#';
    code_table (code_table.COUNT).c128b       := '#';
    code_table (code_table.COUNT).c128c       := '03';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 4;
    code_table (code_table.COUNT).bs_weight   := '121322';
    code_table (code_table.COUNT).c128a       := '$';
    code_table (code_table.COUNT).c128b       := '$';
    code_table (code_table.COUNT).c128c       := '04';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 5;
    code_table (code_table.COUNT).bs_weight   := '131222';
    code_table (code_table.COUNT).c128a       := '?%';
    code_table (code_table.COUNT).c128b       := '?%';
    code_table (code_table.COUNT).c128c       := '05';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 6;
    code_table (code_table.COUNT).bs_weight   := '122213';
    code_table (code_table.COUNT).c128a       := '&';
    code_table (code_table.COUNT).c128b       := '&';
    code_table (code_table.COUNT).c128c       := '06';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 7;
    code_table (code_table.COUNT).bs_weight   := '122312';
    code_table (code_table.COUNT).c128a       := '''';
    code_table (code_table.COUNT).c128b       := '''';
    code_table (code_table.COUNT).c128c       := '07';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 8;
    code_table (code_table.COUNT).bs_weight   := '132212';
    code_table (code_table.COUNT).c128a       := '(';
    code_table (code_table.COUNT).c128b       := '(';
    code_table (code_table.COUNT).c128c       := '08';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 9;
    code_table (code_table.COUNT).bs_weight   := '221213';
    code_table (code_table.COUNT).c128a       := ')';
    code_table (code_table.COUNT).c128b       := ')';
    code_table (code_table.COUNT).c128c       := '09';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 10;
    code_table (code_table.COUNT).bs_weight   := '221312';
    code_table (code_table.COUNT).c128a       := '*';
    code_table (code_table.COUNT).c128b       := '*';
    code_table (code_table.COUNT).c128c       := '10';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 11;
    code_table (code_table.COUNT).bs_weight   := '231212';
    code_table (code_table.COUNT).c128a       := '+';
    code_table (code_table.COUNT).c128b       := '+';
    code_table (code_table.COUNT).c128c       := '11';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 12;
    code_table (code_table.COUNT).bs_weight   := '112232';
    code_table (code_table.COUNT).c128a       := ',';
    code_table (code_table.COUNT).c128b       := ',';
    code_table (code_table.COUNT).c128c       := '12';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 13;
    code_table (code_table.COUNT).bs_weight   := '122132';
    code_table (code_table.COUNT).c128a       := '-';
    code_table (code_table.COUNT).c128b       := '-';
    code_table (code_table.COUNT).c128c       := '13';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 14;
    code_table (code_table.COUNT).bs_weight   := '122231';
    code_table (code_table.COUNT).c128a       := '.';
    code_table (code_table.COUNT).c128b       := '.';
    code_table (code_table.COUNT).c128c       := '14';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 15;
    code_table (code_table.COUNT).bs_weight   := '113222';
    code_table (code_table.COUNT).c128a       := '/';
    code_table (code_table.COUNT).c128b       := '/';
    code_table (code_table.COUNT).c128c       := '15';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 16;
    code_table (code_table.COUNT).bs_weight   := '123122';
    code_table (code_table.COUNT).c128a       := '0';
    code_table (code_table.COUNT).c128b       := '0';
    code_table (code_table.COUNT).c128c       := '16';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 17;
    code_table (code_table.COUNT).bs_weight   := '123221';
    code_table (code_table.COUNT).c128a       := '1';
    code_table (code_table.COUNT).c128b       := '1';
    code_table (code_table.COUNT).c128c       := '17';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 18;
    code_table (code_table.COUNT).bs_weight   := '223211';
    code_table (code_table.COUNT).c128a       := '2';
    code_table (code_table.COUNT).c128b       := '2';
    code_table (code_table.COUNT).c128c       := '18';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 19;
    code_table (code_table.COUNT).bs_weight   := '221132';
    code_table (code_table.COUNT).c128a       := '3';
    code_table (code_table.COUNT).c128b       := '3';
    code_table (code_table.COUNT).c128c       := '19';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 20;
    code_table (code_table.COUNT).bs_weight   := '221231';
    code_table (code_table.COUNT).c128a       := '4';
    code_table (code_table.COUNT).c128b       := '4';
    code_table (code_table.COUNT).c128c       := '20';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 21;
    code_table (code_table.COUNT).bs_weight   := '213212';
    code_table (code_table.COUNT).c128a       := '5';
    code_table (code_table.COUNT).c128b       := '5';
    code_table (code_table.COUNT).c128c       := '21';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 22;
    code_table (code_table.COUNT).bs_weight   := '223112';
    code_table (code_table.COUNT).c128a       := '6';
    code_table (code_table.COUNT).c128b       := '6';
    code_table (code_table.COUNT).c128c       := '22';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 23;
    code_table (code_table.COUNT).bs_weight   := '312131';
    code_table (code_table.COUNT).c128a       := '7';
    code_table (code_table.COUNT).c128b       := '7';
    code_table (code_table.COUNT).c128c       := '23';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 24;
    code_table (code_table.COUNT).bs_weight   := '311222';
    code_table (code_table.COUNT).c128a       := '8';
    code_table (code_table.COUNT).c128b       := '8';
    code_table (code_table.COUNT).c128c       := '24';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 25;
    code_table (code_table.COUNT).bs_weight   := '321122';
    code_table (code_table.COUNT).c128a       := '9';
    code_table (code_table.COUNT).c128b       := '9';
    code_table (code_table.COUNT).c128c       := '25';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 26;
    code_table (code_table.COUNT).bs_weight   := '321221';
    code_table (code_table.COUNT).c128a       := '?:';
    code_table (code_table.COUNT).c128b       := '?:';
    code_table (code_table.COUNT).c128c       := '26';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 27;
    code_table (code_table.COUNT).bs_weight   := '312212';
    code_table (code_table.COUNT).c128a       := '?;';
    code_table (code_table.COUNT).c128b       := '?;';
    code_table (code_table.COUNT).c128c       := '27';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 28;
    code_table (code_table.COUNT).bs_weight   := '322112';
    code_table (code_table.COUNT).c128a       := '<';
    code_table (code_table.COUNT).c128b       := '<';
    code_table (code_table.COUNT).c128c       := '28';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 29;
    code_table (code_table.COUNT).bs_weight   := '322211';
    code_table (code_table.COUNT).c128a       := '=';
    code_table (code_table.COUNT).c128b       := '=';
    code_table (code_table.COUNT).c128c       := '29';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 30;
    code_table (code_table.COUNT).bs_weight   := '212123';
    code_table (code_table.COUNT).c128a       := '>';
    code_table (code_table.COUNT).c128b       := '>';
    code_table (code_table.COUNT).c128c       := '30';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 31;
    code_table (code_table.COUNT).bs_weight   := '212321';
    code_table (code_table.COUNT).c128a       := '??';
    code_table (code_table.COUNT).c128b       := '??';
    code_table (code_table.COUNT).c128c       := '31';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 32;
    code_table (code_table.COUNT).bs_weight   := '232121';
    code_table (code_table.COUNT).c128a       := '@';
    code_table (code_table.COUNT).c128b       := '@';
    code_table (code_table.COUNT).c128c       := '32';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 33;
    code_table (code_table.COUNT).bs_weight   := '111323';
    code_table (code_table.COUNT).c128a       := 'A';
    code_table (code_table.COUNT).c128b       := 'A';
    code_table (code_table.COUNT).c128c       := '33';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 34;
    code_table (code_table.COUNT).bs_weight   := '131123';
    code_table (code_table.COUNT).c128a       := 'B';
    code_table (code_table.COUNT).c128b       := 'B';
    code_table (code_table.COUNT).c128c       := '34';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 35;
    code_table (code_table.COUNT).bs_weight   := '131321';
    code_table (code_table.COUNT).c128a       := 'C';
    code_table (code_table.COUNT).c128b       := 'C';
    code_table (code_table.COUNT).c128c       := '35';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 36;
    code_table (code_table.COUNT).bs_weight   := '112313';
    code_table (code_table.COUNT).c128a       := 'D';
    code_table (code_table.COUNT).c128b       := 'D';
    code_table (code_table.COUNT).c128c       := '36';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 37;
    code_table (code_table.COUNT).bs_weight   := '132113';
    code_table (code_table.COUNT).c128a       := 'E';
    code_table (code_table.COUNT).c128b       := 'E';
    code_table (code_table.COUNT).c128c       := '37';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 38;
    code_table (code_table.COUNT).bs_weight   := '132311';
    code_table (code_table.COUNT).c128a       := 'F';
    code_table (code_table.COUNT).c128b       := 'F';
    code_table (code_table.COUNT).c128c       := '38';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 39;
    code_table (code_table.COUNT).bs_weight   := '211313';
    code_table (code_table.COUNT).c128a       := 'G';
    code_table (code_table.COUNT).c128b       := 'G';
    code_table (code_table.COUNT).c128c       := '39';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 40;
    code_table (code_table.COUNT).bs_weight   := '231113';
    code_table (code_table.COUNT).c128a       := 'H';
    code_table (code_table.COUNT).c128b       := 'H';
    code_table (code_table.COUNT).c128c       := '40';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 41;
    code_table (code_table.COUNT).bs_weight   := '231311';
    code_table (code_table.COUNT).c128a       := 'I';
    code_table (code_table.COUNT).c128b       := 'I';
    code_table (code_table.COUNT).c128c       := '41';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 42;
    code_table (code_table.COUNT).bs_weight   := '112133';
    code_table (code_table.COUNT).c128a       := 'J';
    code_table (code_table.COUNT).c128b       := 'J';
    code_table (code_table.COUNT).c128c       := '42';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 43;
    code_table (code_table.COUNT).bs_weight   := '112331';
    code_table (code_table.COUNT).c128a       := 'K';
    code_table (code_table.COUNT).c128b       := 'K';
    code_table (code_table.COUNT).c128c       := '43';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 44;
    code_table (code_table.COUNT).bs_weight   := '132131';
    code_table (code_table.COUNT).c128a       := 'L';
    code_table (code_table.COUNT).c128b       := 'L';
    code_table (code_table.COUNT).c128c       := '44';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 45;
    code_table (code_table.COUNT).bs_weight   := '113123';
    code_table (code_table.COUNT).c128a       := 'M';
    code_table (code_table.COUNT).c128b       := 'M';
    code_table (code_table.COUNT).c128c       := '45';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 46;
    code_table (code_table.COUNT).bs_weight   := '113321';
    code_table (code_table.COUNT).c128a       := 'N';
    code_table (code_table.COUNT).c128b       := 'N';
    code_table (code_table.COUNT).c128c       := '46';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 47;
    code_table (code_table.COUNT).bs_weight   := '133121';
    code_table (code_table.COUNT).c128a       := 'O';
    code_table (code_table.COUNT).c128b       := 'O';
    code_table (code_table.COUNT).c128c       := '47';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 48;
    code_table (code_table.COUNT).bs_weight   := '313121';
    code_table (code_table.COUNT).c128a       := 'P';
    code_table (code_table.COUNT).c128b       := 'P';
    code_table (code_table.COUNT).c128c       := '48';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 49;
    code_table (code_table.COUNT).bs_weight   := '211331';
    code_table (code_table.COUNT).c128a       := 'Q';
    code_table (code_table.COUNT).c128b       := 'Q';
    code_table (code_table.COUNT).c128c       := '49';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 50;
    code_table (code_table.COUNT).bs_weight   := '231131';
    code_table (code_table.COUNT).c128a       := 'R';
    code_table (code_table.COUNT).c128b       := 'R';
    code_table (code_table.COUNT).c128c       := '50';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 51;
    code_table (code_table.COUNT).bs_weight   := '213113';
    code_table (code_table.COUNT).c128a       := 'S';
    code_table (code_table.COUNT).c128b       := 'S';
    code_table (code_table.COUNT).c128c       := '51';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 52;
    code_table (code_table.COUNT).bs_weight   := '213311';
    code_table (code_table.COUNT).c128a       := 'T';
    code_table (code_table.COUNT).c128b       := 'T';
    code_table (code_table.COUNT).c128c       := '52';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 53;
    code_table (code_table.COUNT).bs_weight   := '213131';
    code_table (code_table.COUNT).c128a       := 'U';
    code_table (code_table.COUNT).c128b       := 'U';
    code_table (code_table.COUNT).c128c       := '53';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 54;
    code_table (code_table.COUNT).bs_weight   := '311123';
    code_table (code_table.COUNT).c128a       := 'V';
    code_table (code_table.COUNT).c128b       := 'V';
    code_table (code_table.COUNT).c128c       := '54';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 55;
    code_table (code_table.COUNT).bs_weight   := '311321';
    code_table (code_table.COUNT).c128a       := 'W';
    code_table (code_table.COUNT).c128b       := 'W';
    code_table (code_table.COUNT).c128c       := '55';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 56;
    code_table (code_table.COUNT).bs_weight   := '331121';
    code_table (code_table.COUNT).c128a       := 'X';
    code_table (code_table.COUNT).c128b       := 'X';
    code_table (code_table.COUNT).c128c       := '56';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 57;
    code_table (code_table.COUNT).bs_weight   := '312113';
    code_table (code_table.COUNT).c128a       := 'Y';
    code_table (code_table.COUNT).c128b       := 'Y';
    code_table (code_table.COUNT).c128c       := '57';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 58;
    code_table (code_table.COUNT).bs_weight   := '312311';
    code_table (code_table.COUNT).c128a       := 'Z';
    code_table (code_table.COUNT).c128b       := 'Z';
    code_table (code_table.COUNT).c128c       := '58';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 59;
    code_table (code_table.COUNT).bs_weight   := '332111';
    code_table (code_table.COUNT).c128a       := '[';
    code_table (code_table.COUNT).c128b       := '[';
    code_table (code_table.COUNT).c128c       := '59';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 60;
    code_table (code_table.COUNT).bs_weight   := '314111';
    code_table (code_table.COUNT).c128a       := '\';
    code_table (code_table.COUNT).c128b       := '\';
    code_table (code_table.COUNT).c128c       := '60';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 61;
    code_table (code_table.COUNT).bs_weight   := '221411';
    code_table (code_table.COUNT).c128a       := ']';
    code_table (code_table.COUNT).c128b       := ']';
    code_table (code_table.COUNT).c128c       := '61';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 62;
    code_table (code_table.COUNT).bs_weight   := '431111';
    code_table (code_table.COUNT).c128a       := '^';
    code_table (code_table.COUNT).c128b       := '^';
    code_table (code_table.COUNT).c128c       := '62';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 63;
    code_table (code_table.COUNT).bs_weight   := '111224';
    code_table (code_table.COUNT).c128a       := '_';
    code_table (code_table.COUNT).c128b       := '_';
    code_table (code_table.COUNT).c128c       := '63';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 64;
    code_table (code_table.COUNT).bs_weight   := '111422';
    code_table (code_table.COUNT).c128a       := 'NUL';
    code_table (code_table.COUNT).c128b       := '`';
    code_table (code_table.COUNT).c128c       := '64';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 65;
    code_table (code_table.COUNT).bs_weight   := '121124';
    code_table (code_table.COUNT).c128a       := 'SOH';
    code_table (code_table.COUNT).c128b       := 'a';
    code_table (code_table.COUNT).c128c       := '65';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 66;
    code_table (code_table.COUNT).bs_weight   := '121421';
    code_table (code_table.COUNT).c128a       := 'STX';
    code_table (code_table.COUNT).c128b       := 'b';
    code_table (code_table.COUNT).c128c       := '66';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 67;
    code_table (code_table.COUNT).bs_weight   := '141122';
    code_table (code_table.COUNT).c128a       := 'ETX';
    code_table (code_table.COUNT).c128b       := 'c';
    code_table (code_table.COUNT).c128c       := '67';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 68;
    code_table (code_table.COUNT).bs_weight   := '141221';
    code_table (code_table.COUNT).c128a       := 'EOT';
    code_table (code_table.COUNT).c128b       := 'd';
    code_table (code_table.COUNT).c128c       := '68';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 69;
    code_table (code_table.COUNT).bs_weight   := '112214';
    code_table (code_table.COUNT).c128a       := 'ENQ';
    code_table (code_table.COUNT).c128b       := 'e';
    code_table (code_table.COUNT).c128c       := '69';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 70;
    code_table (code_table.COUNT).bs_weight   := '112412';
    code_table (code_table.COUNT).c128a       := 'ACK';
    code_table (code_table.COUNT).c128b       := 'f';
    code_table (code_table.COUNT).c128c       := '70';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 71;
    code_table (code_table.COUNT).bs_weight   := '122114';
    code_table (code_table.COUNT).c128a       := 'BEL';
    code_table (code_table.COUNT).c128b       := 'g';
    code_table (code_table.COUNT).c128c       := '71';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 72;
    code_table (code_table.COUNT).bs_weight   := '122411';
    code_table (code_table.COUNT).c128a       := 'BS';
    code_table (code_table.COUNT).c128b       := 'h';
    code_table (code_table.COUNT).c128c       := '72';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 73;
    code_table (code_table.COUNT).bs_weight   := '142112';
    code_table (code_table.COUNT).c128a       := 'HT';
    code_table (code_table.COUNT).c128b       := 'i';
    code_table (code_table.COUNT).c128c       := '73';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 74;
    code_table (code_table.COUNT).bs_weight   := '142211';
    code_table (code_table.COUNT).c128a       := 'LF';
    code_table (code_table.COUNT).c128b       := 'j';
    code_table (code_table.COUNT).c128c       := '74';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 75;
    code_table (code_table.COUNT).bs_weight   := '241211';
    code_table (code_table.COUNT).c128a       := 'VT';
    code_table (code_table.COUNT).c128b       := 'k';
    code_table (code_table.COUNT).c128c       := '75';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 76;
    code_table (code_table.COUNT).bs_weight   := '221114';
    code_table (code_table.COUNT).c128a       := 'FF';
    code_table (code_table.COUNT).c128b       := 'l';
    code_table (code_table.COUNT).c128c       := '76';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 77;
    code_table (code_table.COUNT).bs_weight   := '413111';
    code_table (code_table.COUNT).c128a       := 'CR';
    code_table (code_table.COUNT).c128b       := 'm';
    code_table (code_table.COUNT).c128c       := '77';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 78;
    code_table (code_table.COUNT).bs_weight   := '241112';
    code_table (code_table.COUNT).c128a       := 'SO';
    code_table (code_table.COUNT).c128b       := 'n';
    code_table (code_table.COUNT).c128c       := '78';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 79;
    code_table (code_table.COUNT).bs_weight   := '134111';
    code_table (code_table.COUNT).c128a       := 'SI';
    code_table (code_table.COUNT).c128b       := 'o';
    code_table (code_table.COUNT).c128c       := '79';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 80;
    code_table (code_table.COUNT).bs_weight   := '111242';
    code_table (code_table.COUNT).c128a       := 'DLE';
    code_table (code_table.COUNT).c128b       := 'p';
    code_table (code_table.COUNT).c128c       := '80';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 81;
    code_table (code_table.COUNT).bs_weight   := '121142';
    code_table (code_table.COUNT).c128a       := 'DC1';
    code_table (code_table.COUNT).c128b       := 'q';
    code_table (code_table.COUNT).c128c       := '81';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 82;
    code_table (code_table.COUNT).bs_weight   := '121241';
    code_table (code_table.COUNT).c128a       := 'DC2';
    code_table (code_table.COUNT).c128b       := 'r';
    code_table (code_table.COUNT).c128c       := '82';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 83;
    code_table (code_table.COUNT).bs_weight   := '114212';
    code_table (code_table.COUNT).c128a       := 'DC3';
    code_table (code_table.COUNT).c128b       := 's';
    code_table (code_table.COUNT).c128c       := '83';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 84;
    code_table (code_table.COUNT).bs_weight   := '124112';
    code_table (code_table.COUNT).c128a       := 'DC4';
    code_table (code_table.COUNT).c128b       := 't';
    code_table (code_table.COUNT).c128c       := '84';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 85;
    code_table (code_table.COUNT).bs_weight   := '124211';
    code_table (code_table.COUNT).c128a       := 'NAK';
    code_table (code_table.COUNT).c128b       := 'u';
    code_table (code_table.COUNT).c128c       := '85';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 86;
    code_table (code_table.COUNT).bs_weight   := '411212';
    code_table (code_table.COUNT).c128a       := 'SYN';
    code_table (code_table.COUNT).c128b       := 'v';
    code_table (code_table.COUNT).c128c       := '86';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 87;
    code_table (code_table.COUNT).bs_weight   := '421112';
    code_table (code_table.COUNT).c128a       := 'ETB';
    code_table (code_table.COUNT).c128b       := 'w';
    code_table (code_table.COUNT).c128c       := '87';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 88;
    code_table (code_table.COUNT).bs_weight   := '421211';
    code_table (code_table.COUNT).c128a       := 'CAN';
    code_table (code_table.COUNT).c128b       := 'x';
    code_table (code_table.COUNT).c128c       := '88';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 89;
    code_table (code_table.COUNT).bs_weight   := '212141';
    code_table (code_table.COUNT).c128a       := 'EM';
    code_table (code_table.COUNT).c128b       := 'y';
    code_table (code_table.COUNT).c128c       := '89';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 90;
    code_table (code_table.COUNT).bs_weight   := '214121';
    code_table (code_table.COUNT).c128a       := 'SUB';
    code_table (code_table.COUNT).c128b       := 'z';
    code_table (code_table.COUNT).c128c       := '90';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 91;
    code_table (code_table.COUNT).bs_weight   := '412121';
    code_table (code_table.COUNT).c128a       := 'ESC';
    code_table (code_table.COUNT).c128b       := '{';
    code_table (code_table.COUNT).c128c       := '91';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 92;
    code_table (code_table.COUNT).bs_weight   := '111143';
    code_table (code_table.COUNT).c128a       := 'FS';
    code_table (code_table.COUNT).c128b       := '|';
    code_table (code_table.COUNT).c128c       := '92';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 93;
    code_table (code_table.COUNT).bs_weight   := '111341';
    code_table (code_table.COUNT).c128a       := 'GS';
    code_table (code_table.COUNT).c128b       := '}';
    code_table (code_table.COUNT).c128c       := '93';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 94;
    code_table (code_table.COUNT).bs_weight   := '131141';
    code_table (code_table.COUNT).c128a       := 'RS';
    code_table (code_table.COUNT).c128b       := '~';
    code_table (code_table.COUNT).c128c       := '94';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 95;
    code_table (code_table.COUNT).bs_weight   := '114113';
    code_table (code_table.COUNT).c128a       := 'US';
    code_table (code_table.COUNT).c128b       := 'DEL';
    code_table (code_table.COUNT).c128c       := '95';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 96;
    code_table (code_table.COUNT).bs_weight   := '114311';
    code_table (code_table.COUNT).c128a       := 'FNC 3';
    code_table (code_table.COUNT).c128b       := 'FNC 3';
    code_table (code_table.COUNT).c128c       := '96';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 97;
    code_table (code_table.COUNT).bs_weight   := '411113';
    code_table (code_table.COUNT).c128a       := 'FNC 2';
    code_table (code_table.COUNT).c128b       := 'FNC 2';
    code_table (code_table.COUNT).c128c       := '97';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 98;
    code_table (code_table.COUNT).bs_weight   := '411311';
    code_table (code_table.COUNT).c128a       := 'Shift B';
    code_table (code_table.COUNT).c128b       := 'Shift A';
    code_table (code_table.COUNT).c128c       := '98';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 99;
    code_table (code_table.COUNT).bs_weight   := '113141';
    code_table (code_table.COUNT).c128a       := 'Code C';
    code_table (code_table.COUNT).c128b       := 'Code C';
    code_table (code_table.COUNT).c128c       := '99';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 100;
    code_table (code_table.COUNT).bs_weight   := '114131';
    code_table (code_table.COUNT).c128a       := 'Code B';
    code_table (code_table.COUNT).c128b       := 'FNC4';
    code_table (code_table.COUNT).c128c       := 'Code B';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 101;
    code_table (code_table.COUNT).bs_weight   := '311141';
    code_table (code_table.COUNT).c128a       := 'FNC 4';
    code_table (code_table.COUNT).c128b       := 'Code A';
    code_table (code_table.COUNT).c128c       := 'Code A';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 102;
    code_table (code_table.COUNT).bs_weight   := '411131';
    code_table (code_table.COUNT).c128a       := 'FNC 1';
    code_table (code_table.COUNT).c128b       := 'FNC 1';
    code_table (code_table.COUNT).c128c       := 'FNC 1';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 103;
    code_table (code_table.COUNT).bs_weight   := '211412';
    code_table (code_table.COUNT).c128a       := 'Start Code A';
    code_table (code_table.COUNT).c128b       := 'Start Code A';
    code_table (code_table.COUNT).c128c       := 'Start Code A';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 104;
    code_table (code_table.COUNT).bs_weight   := '211214';
    code_table (code_table.COUNT).c128a       := 'Start Code B';
    code_table (code_table.COUNT).c128b       := 'Start Code B';
    code_table (code_table.COUNT).c128c       := 'Start Code B';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 105;
    code_table (code_table.COUNT).bs_weight   := '211232';
    code_table (code_table.COUNT).c128a       := 'Start Code C';
    code_table (code_table.COUNT).c128b       := 'Start Code C';
    code_table (code_table.COUNT).c128c       := 'Start Code C';
    code_table.EXTEND;
    code_table (code_table.COUNT).vlue        := 106;
    code_table (code_table.COUNT).bs_weight   := '23311124';
    code_table (code_table.COUNT).c128a       := 'Stop';
    code_table (code_table.COUNT).c128b       := 'Stop';
    code_table (code_table.COUNT).c128c       := 'Stop';

    FOR i IN 1 .. code_table.COUNT
    LOOP
        FOR j IN 1 .. LENGTH (code_table (i).bs_weight) / 2
        LOOP
            code_table (i).chars   :=
                   code_table (i).chars
                || CHR (
                           (TRUNC (TO_NUMBER (SUBSTR (code_table (i).bs_weight, (j - 1) * 2 + 1, 2)) / 10) - 1)
                         * 4
                       + MOD (
                             TO_NUMBER (
                                 SUBSTR (code_table (i).bs_weight,
                                         (j - 1) * 2 + 1,
                                         2)),
                             10)
                       - 1
                       + ASCII ('A'));
        END LOOP;
    END LOOP;
END;
/


GRANT EXECUTE ON APPS.XXDO_CODE128 TO APPSRO
/
