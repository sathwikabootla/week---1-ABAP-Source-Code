REPORT z_sales_order_perf_optimized.
PARAMETERS: p_date TYPE vbak-erdat OBLIGATORY DEFAULT sy-datum.
TYPES: BEGIN OF ty_result,
         vbeln TYPE vbak-vbeln, " Sales Document
         erdat TYPE vbak-erdat, " Creation Date
         kunnr TYPE vbak-kunnr, " Sold-To Party
         posnr TYPE vbap-posnr, " Sales Order Line Item
         matnr TYPE vbap-matnr, " Material Number
       END OF ty_result.
DATA: lt_result TYPE STANDARD TABLE OF ty_result WITH EMPTY KEY.
START-OF-SELECTION.
  SELECT FROM vbak AS a
    INNER JOIN vbap AS b
      ON a~vbeln = b~vbeln
    FIELDS a~vbeln,
           a~erdat,
           a~kunnr,
           b~posnr,
           b~matnr
    WHERE a~erdat >= @p_date
    INTO TABLE @lt_result.
  IF lt_result IS NOT INITIAL.
     WRITE: / 'Sales Order Optimization Tracking Report Matrix', 
    LOOP AT lt_result INTO DATA (ls_final_row).
      WRITE: / ls_final_row-vbeln, 
               ls_final_row-erdat, 
               ls_final_row-kunnr, 
               ls_final_row-posnr, 
               ls_final_row-matnr.
ENDLOOP.
     ELSE.
    WRITE: / 'No matching transactional sales documentation found for date criteria:', p_date.
  ENDIF.
