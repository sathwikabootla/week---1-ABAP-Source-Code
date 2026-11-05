REPORT zsales_process_correct_ecc.
DATA: lt_vbap TYPE STANDARD TABLE OF vbap,
            lt_vbak TYPE STANDARD TABLE OF vbak,
            ls_vbap TYPE vbap,
            ls_vbak TYPE vbak,
            lv_total_weight TYPE p DECIMALS 3.
PARAMETERS: p_vbeln TYPE vbak-vbeln.
START-OF-SELECTION.
IF p_vbeln IS INITIAL.
    MESSAGE 'Error: Please enter a valid Sales Order Number!' TYPE 'E'.
    EXIT.
  ENDIF.
 SELECT * FROM vbap 
    INTO TABLE lt_vbap 
    WHERE vbeln = p_vbeln.
  IF lt_vbap IS INITIAL.
    MESSAGE 'Information: No items found for this Sales Order.' TYPE 'I'.
    EXIT.
  ELSE.
    SELECT * FROM vbak 
INTO TABLE lt_vbak
      FOR ALL ENTRIES IN lt_vbap
      WHERE vbeln = lt_vbap-vbeln.
  ENDIF.
  LOOP AT lt_vbap INTO ls_vbap.
     lv_total_weight = lv_total_weight + ls_vbap-brgew.
    CLEAR ls_vbap. 
  ENDLOOP.
FORMAT COLOR COL_HEADING.
  WRITE: / ' SALES PROCESSING ORDER MANAGEMENT REPORT '.
 FORMAT RESET.
  WRITE: / ' Sales Order Processed Successfully: ', p_vbeln.
FORMAT COLOR COL_TOTAL.
  WRITE: / 'Total Calculated Weight:     ', lv_total_weight, 'KG'.
FORMAT RESET.
