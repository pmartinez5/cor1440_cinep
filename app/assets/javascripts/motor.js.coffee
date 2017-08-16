# You can use CoffeeScript in this file: http://coffeescript.org/

#//= require sip/motor
#//= require heb412_gen/motor
#//= require jquery-ui/widgets/autocomplete
#//= require cocoon

@reconocer_decimal_locale_es_CO = (n) ->
  i = 0
  r = ""
  while i<n.length
    if n[i] == ','
      r = r + '.'
    if n[i] >= '0' && n[i] <='9'
      r = r + n[i]
    i++
  return parseFloat(r)
    
@recalcula_montopesos_localizado = (root) ->
  tm = $('#proyectofinanciero_tipomoneda_id').val()
  ml = $('#proyectofinanciero_monto_localizado').val()
  if tm == "1"  # PESO
    $('#proyectofinanciero_montopesos_localizado').val(ml)
  else if typeof ml != 'undefined' && typeof tm != 'undefined'
    tf2 = $('#proyectofinanciero_tasaformulacion_id option:selected').text().split(' ')
    if tf2.length != 2
      return
    tf = reconocer_decimal_locale_es_CO(tf2[1])
    m = reconocer_decimal_locale_es_CO(ml)
    mp = tf*m
    mpl = new Intl.NumberFormat('es-CO').format(mp)
    $('#proyectofinanciero_montopesos_localizado').val(mpl)
    
  return


@cor1440_cinep_prepara_eventos_unicos = (root) ->
  sip_arregla_puntomontaje(root)
  $('#proyectofinanciero_tipomoneda_id').chosen().change( (e) ->
    sip_llena_select_con_AJAX($(this), 'proyectofinanciero_tasaformulacion_id', 'tasascambio', 'bustipomoneda_id', 'con Tasa de cambio', root, true, 'id', 'presenta_nombre', recalcula_montopesos_localizado)
  )
  $('#proyectofinanciero_monto_localizado').change( (e) ->
    recalcula_montopesos_localizado(root)
  )
  $('#proyectofinanciero_tasaformulacion_id').chosen().change( (e) ->
    recalcula_montopesos_localizado(root)
  )

  return

