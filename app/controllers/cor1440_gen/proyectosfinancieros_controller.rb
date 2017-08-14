# encoding: UTF-8

require 'cor1440_gen/concerns/controllers/proyectosfinancieros_controller'

module Cor1440Gen
  class ProyectosfinancierosController < Sip::ModelosController
    helper ::ApplicationHelper
    include ::ApplicationHelper
    include Cor1440Gen::Concerns::Controllers::ProyectosfinancierosController
    include ::Sip::ModeloHelper

    before_action :set_proyectofinanciero, 
      only: [:show, :edit, :update, :destroy]
    load_and_authorize_resource class: Cor1440Gen::Proyectofinanciero

    include Sip::ConsultasHelper

    def cadena_muchos(r, campo, sep = ', ', camponom='nombre')
        if !r.send(campo)
          return ""
        end
        return r.send(campo).inject('') { |memo, i|
          (memo == '' ? '' : memo + sep) + i.send(camponom)
        }
    end

    def atributos_index
      [ "id", 
        "referenciacinep",
        "nombre",
      ] +
        [ :financiador_ids =>  [] ] +
        [ "fechainicio_localizada",
          "fechacierre_localizada"
      ] +
        [ :uresponsable_ids =>  [] ] +
        [ 
          "monto"
      ] 
    end

    def new
      @registro = clase.constantize.new
      @registro.monto = 1
      @registro.montopesos = 1
      @registro.presupuestototal = 1
      @registro.tipomoneda = ::Tipomoneda.where(codiso4217: 'COP').take
      #@registro.tasacambio = 1
      render layout: 'application'
    end

    def vista_solicitud_informes
      cons = ""
      pre = ""
      [['informenarrativo','INFOMRE NARRATIVO'], 
       ['informefinanciero', 'INFORME FINANCIERO'],
       ['informeauditoria', 'INFORME DE AUDITORÍA']].each do |i|
        cons += pre 
        cons += "SELECT proyectofinanciero_id, fechaplaneada, fechareal, 
          devoluciones,
          '#{i[1]}: ' || detalle as observaciones, seguimiento
          FROM #{i[0]}"
        pre = " UNION "
      end

      cons += pre 
      cons += "SELECT proyectofinanciero_id, fechaplaneada, fechareal, 
        devoluciones,
        tipoproductopf.nombre || ': ' || detalle as observaciones, 
        seguimiento
        FROM productopf JOIN tipoproductopf
        ON productopf.tipoproductopf_id=tipoproductopf.id"
      
      w = @registros.count > 0 ?  
        "WHERE p.id in (#{@registros.pluck(:id).join(", ")})" : ""

      Heb412Gen::Plantillahcm.connection.execute <<-SQL
      DROP VIEW IF EXISTS v_solicitud_informes ;
      DROP VIEW IF EXISTS v_solicitud_informes1 ;
      CREATE VIEW v_solicitud_informes1 AS (#{cons});
      CREATE VIEW v_solicitud_informes AS (
      SELECT p.id AS compromiso_id, p.referenciacinep AS titulo, 
      ARRAY_TO_STRING(ARRAY(SELECT nombres || ' ' || apellidos FROM 
        usuario JOIN coordinador_proyectofinanciero 
        ON usuario.id=coordinador_proyectofinanciero.coordinador_id
        WHERE proyectofinanciero_id=p.id), ', ') AS coordinador,
      ARRAY_TO_STRING(ARRAY(SELECT nombres || ' ' || apellidos FROM 
        usuario JOIN proyectofinanciero_uresponsable
        ON usuario.id=proyectofinanciero_uresponsable.uresponsable_id
        WHERE proyectofinanciero_id=p.id), ', ') AS responsable,
      fechaplaneada, fechareal,
      CASE WHEN devoluciones THEN 'SI' 
        WHEN devoluciones IS NULL THEN '' 
        ELSE 'NO' END AS devoluciones,
      s.observaciones as observaciones, seguimiento, 
      CASE WHEN fechareal<=fechaplaneada THEN 'SI'
        WHEN fechareal>fechaplaneada THEN 'NO'
        WHEN fechareal IS NULL AND CURRENT_DATE>fechaplaneada THEN 'NO'
        ELSE '' END AS a_tiempo
      FROM cor1440_gen_proyectofinanciero AS p
      JOIN v_solicitud_informes1 AS s
      ON p.id=s.proyectofinanciero_id
      #{w}
      ORDER BY s.fechaplaneada
      )
      SQL
      return Heb412Gen::Plantillahcm.find_by_sql(
        'SELECT * FROM v_solicitud_informes')
      #return @registros.joins('JOIN v_solicitud_informes ON cor1440_gen_proyectofinanciero.id=v_solicitud_informes.compromiso_id').select('v_solicitud_informes.*')
    end

    def asigna_celda_y_borde(hoja, fila, col, valor)
        hoja[fila, col] = valor
        hoja.cell(fila, col).format.top.style = 'solid'
        hoja.cell(fila, col).format.bottom.style = 'solid'
        hoja.cell(fila, col).format.right.style = 'solid'
        hoja.cell(fila, col).format.left.style = 'solid'
    end

    
    def tramitado_anio(hoja, anio)
      hoja.name = "Tramitados #{anio}"
      reg = @registros.where("fechaformulacion>='#{anio.to_i}-01-01' AND " +
                             "fechaformulacion<='#{anio.to_i}-12-31'").reorder(
                               [:referenciacinep, :id])
      fila = 2
      cons = 1
      reg.each do |r|
        asigna_celda_y_borde(hoja, fila, 1, cons)
        mf = r.fechaformulacion ?
          r.fechaformulacion_localizada[3..5] : ''
        asigna_celda_y_borde(hoja, fila, 2, mf)
        asigna_celda_y_borde(hoja, fila, 3, r.referenciacinep)
        asigna_celda_y_borde(hoja, fila, 4, 
                             cadena_muchos(r, 'financiador', ' - '))
        asigna_celda_y_borde(hoja, fila, 5, 
                             Sip::ModeloHelper.etiqueta_coleccion(
                               ApplicationHelper::ESTADO, r.estado))
        asigna_celda_y_borde(hoja, fila, 6, r.monto_localizado)
        asigna_celda_y_borde(hoja, fila, 7, r.tipomoneda ?
                             r.tipomoneda.codiso4217 : '')
        asigna_celda_y_borde(hoja, fila, 8, 
                             r.montopesos_localizado)
        asigna_celda_y_borde(hoja, fila, 9, 
                             cadena_muchos(r, 'grupo', '; '))
        asigna_celda_y_borde(hoja, fila, 10, r.observacionestramite)

        cons +=1
        fila +=1
      end
    end


    def cuadro_general_seguimiento(pl)
      ruta = File.join(Rails.application.config.x.heb412_ruta, 
                       pl.ruta).to_s
      puts "ruta=#{ruta}"
      libro = Rspreadsheet.open(ruta)

      # Hoja Resumen
      hoja = libro.worksheets(1)
      fila = 2
      reg = @registros.where("estado IN ('J', 'E', 'C', 'T')").
        reorder([:referenciacinep, :id])
      cons = 1
      reg.each do |r|
        asigna_celda_y_borde(hoja, fila, 1, cons)
        asigna_celda_y_borde(hoja, fila, 2, r.referenciacinep)
        asigna_celda_y_borde(hoja, fila, 3, 
                             cadena_muchos(r, 'financiador', ' - '))
        asigna_celda_y_borde(hoja, fila, 4, r.respgp ?
                             r.respgp.presenta_nombre : '')
        asigna_celda_y_borde(hoja, fila, 5, 
                             Sip::ModeloHelper.etiqueta_coleccion(
                               ApplicationHelper::ESTADO, r.estado))
        asigna_celda_y_borde(hoja, fila, 6, 
                             Sip::ModeloHelper.etiqueta_coleccion(
                               ApplicationHelper::DIFICULTAD, r.dificultad))
        cons +=1
        fila +=1
      end

      # Hoja En tramite
      hoja = libro.worksheets(2)
      fila = 2
      reg = @registros.where("estado IN ('E')").
        reorder([:referenciacinep, :id])
      cons = 1
      reg.each do |r|
        asigna_celda_y_borde(hoja, fila, 1, cons)
        asigna_celda_y_borde(hoja, fila, 2, r.referenciacinep)
        asigna_celda_y_borde(hoja, fila, 3, 
                             cadena_muchos(r, 'financiador', ' - '))
        gp = r.respgp ? "GP: " + r.respgp.presenta_nombre : ""
        ao = cadena_muchos(r, 'uresponsable', ', ', 'presenta_nombre')
        if ao != ''
          ao = "; AO: #{ao}"
        end
        asigna_celda_y_borde(hoja, fila, 4, "#{gp}#{ao}")
        asigna_celda_y_borde(hoja, fila, 5, cadena_muchos(
          r, 'usuario', ', ', 'presenta_nombre'))
        asigna_celda_y_borde(hoja, fila, 6, 
                             Sip::ModeloHelper.etiqueta_coleccion(
                               ApplicationHelper::ESTADO, r.estado))
        asigna_celda_y_borde(hoja, fila, 7, r.monto_localizado)
        asigna_celda_y_borde(hoja, fila, 8, r.tipomoneda ?
                             r.tipomoneda.codiso4217 : '')
        asigna_celda_y_borde(hoja, fila, 9, 
                             r.montopesos_localizado)
        duryf = r.fechacierre && r.fechainicio ?
          (dif_meses_dias(r.fechainicio, r.fechacierre) + ' - ' + 
           r.fechainicio_localizada) : ''
        asigna_celda_y_borde(hoja, fila, 10, duryf)
        asigna_celda_y_borde(hoja, fila, 11, r.observacionestramite)
        mf = r.fechaformulacion ?
          r.fechaformulacion_localizada[3..-1] : ''
        asigna_celda_y_borde(hoja, fila, 12, mf)

        cons +=1
        fila +=1
      end

      # Hoja Ejecucion
      hoja = libro.worksheets(3)
      fila = 2
      reg = @registros.where("estado IN ('J')").
        reorder([:referenciacinep, :id])
      cons = 1
      reg.each do |r|
        asigna_celda_y_borde(hoja, fila, 1, cons)
        asigna_celda_y_borde(hoja, fila, 2, r.referenciacinep)
        asigna_celda_y_borde(hoja, fila, 3, r.referencia)
        asigna_celda_y_borde(hoja, fila, 4, r.nombre)
        asigna_celda_y_borde(hoja, fila, 5, 
                             cadena_muchos(r, 'financiador', ' - '))
        asigna_celda_y_borde(hoja, fila, 6, r.respgp ?
                             r.respgp.presenta_nombre : '')
        asigna_celda_y_borde(hoja, fila, 7, r.observacionesejecucion)
        asigna_celda_y_borde(hoja, fila, 8, 
                             cadena_muchos(r, 'grupo', '; '))

        cons +=1
        fila +=1
      end

      # Hoja En cierre
      hoja = libro.worksheets(4)
      fila = 2
      reg = @registros.where("estado IN ('C')").
        reorder([:referenciacinep, :id])
      cons = 1
      reg.each do |r|
        asigna_celda_y_borde(hoja, fila, 1, cons)
        asigna_celda_y_borde(hoja, fila, 2, r.referenciacinep)
        asigna_celda_y_borde(hoja, fila, 3, r.referencia)
        asigna_celda_y_borde(hoja, fila, 4, r.objeto)
        asigna_celda_y_borde(hoja, fila, 5, 
                             cadena_muchos(r, 'financiador', ' - '))
        asigna_celda_y_borde(hoja, fila, 6, r.respgp ? 
                             r.respgp.presenta_nombre : '')
        asigna_celda_y_borde(hoja, fila, 7, r.observacionescierre)
        asigna_celda_y_borde(hoja, fila, 8, 
                             cadena_muchos(r, 'grupo', '; '))

        cons +=1
        fila +=1
      end

      # Hoja Tramitados del año actual
      treste = libro.worksheets(5)
      anio = Date.today.year
      tramitado_anio(treste, anio)

      # Hoja de publicaciones
      hoja = libro.worksheets(7)
      fila = 2
      reg = @registros.where("estado IN ('J', 'C', 'T')").
        joins(:productopf).reorder([:referenciacinep, :id])
      cons = 1
      reg.each do |r|
        asigna_celda_y_borde(hoja, fila, 1, cons)
        asigna_celda_y_borde(hoja, fila, 2, r.referenciacinep)
        asigna_celda_y_borde(hoja, fila, 3, 
                             cadena_muchos(r, 'coordinador', ', ', 
                                           'presenta_nombre'))
        asigna_celda_y_borde(hoja, fila, 4, 
                             cadena_muchos(r, 'financiador', ' - '))
        asigna_celda_y_borde(hoja, fila, 5, r.referencia)
        asigna_celda_y_borde(hoja, fila, 6, r.fechainicio_localizada)
        asigna_celda_y_borde(hoja, fila, 7, r.fechacierre_localizada)

        # Tocara hacerlo como consulta porque no logramos sacar
        # aqui los campos de productopf haciendolo asi
        cons +=1
        fila +=1
      end

     
      # Hojas para tramitados en años anteriores
      anios = @registros.where("fechaformulacion<'#{anio}-01-01'").
        reorder(nil).pluck('DISTINCT EXTRACT(YEAR FROM fechaformulacion)').
        map {|a| a.to_i}
      anios.sort!
      numhoja = 9
      anios.each do |anio|
        if numhoja<=11
          hoja = libro.worksheets(numhoja)
          tramitado_anio(hoja, anio)
        end
      end

      n=File.join('/tmp', File.basename(pl.ruta))
      libro.save(n)

      return n
    end
 
       
    def index_otros_formatos(format, params)
      format.ods {
        if params[:idplantilla].nil? or params[:idplantilla].to_i <= 0 then
          head :no_content 
        elsif Heb412Gen::Plantillahcm.where(
          id: params[:idplantilla].to_i).take.nil?
          head :no_content 
        else
          pl = Heb412Gen::Plantillahcm.find(
            params[:idplantilla].to_i)
          if pl.vista == 'Solicitud de Informe'
            @vista = vista_solicitud_informes
            n = Heb412Gen::PlantillahcmController.
              llena_plantilla_multiple_fd(pl, @vista)
          elsif pl.vista == 'Cuadro General de Seguimiento'
            n = cuadro_general_seguimiento(pl)
          end
          send_file n, x_sendfile: true
        end
      }
    end

    def index_reordenar(registros)
      @plantillas = Heb412Gen::Plantillahcm.where(
        "vista IN ('Solicitud de Informe', 'Cuadro General de Seguimiento')").
        select('nombremenu, id').map { 
          |co| [co.nombremenu, co.id] 
        }
      return registros.reorder([:referenciacinep, :id])
    end

    def genera_odf
      # Ejemplo de https://github.com/sandrods/odf-report
      report = ODFReport::Report.new("#{Rails.root}/app/reportes/Plantilla-RE-SC-07.odt") do |r|
        cn = [:nombre, :referencia, :referenciacinep, 
              :respagencia, :emailrespagencia,
              :telrespagencia, :fuentefinanciador, :observaciones,
              :saldo, :otrosaportescinep,
              :empresaauditoria,
              :centrocosto, :cuentasbancarias, 
              :sucursal, :rendimientosfinancieros,
              :informesespecificos, :informessolicitudpago, 
              :anotacionescontab, :gestiones]
              #:formatosespecificos, :formatossolicitudpago ]
        cn.each do |s|
          r.add_field(s, @proyectofinanciero[s] ? @proyectofinanciero[s] : '')
        end

        # Booleanos
        bn = [:acuse, :autenticarcompulsar, :copiasdesoporte, 
              :reportarrendimientosfinancieros,
              :reinvertirrendimientosfinancieros]
        bn.each do |b|
          r.add_field(b, @proyectofinanciero[b] ? 'Si' : 'No')
        end

        # Renombrados
        r.add_field(:aportefinanciador, 
                    @proyectofinanciero.monto_localizado)
        r.add_field(:saldo, 
                    @proyectofinanciero.saldo_localizado)
        r.add_field(:aportefinancierocinep, 
                    @proyectofinanciero.aportecinep_localizado)
        r.add_field(:presupuestototal, 
                    @proyectofinanciero.presupuestototal_localizado)
        r.add_field(:publicaciones, 
                    @proyectofinanciero[:compromisos])
        r.add_field(:fechainicio, 
                    @proyectofinanciero.fechainicio_localizada)
        r.add_field(:fechacierre, 
                    @proyectofinanciero.fechacierre_localizada)
        r.add_field(:fechaliquidacion, 
                    @proyectofinanciero.fechaliquidacion_localizada)

        # Calculados
        if @proyectofinanciero.fechainicio && @proyectofinanciero.fechacierre
          r.add_field(:duracion, dif_meses_dias(@proyectofinanciero.fechainicio, 
                                                @proyectofinanciero.fechacierre))
        end
        ca = [:anotacionesdb, :anotacionesrh, :anotacionesre,
              :anotacionesinf, :anotacionescontab]
        an = ""
        sep = ""
        ca.each do |a|
          if @proyectofinanciero[a] then
            nan = @proyectofinanciero[a].strip
            if (nan != '' && !nan.end_with?(".")) then
              nan += "."
            end
            an += sep + nan
            sep = "   "
          end
        end
        r.add_field(:anotaciones, an)
        cf = @proyectofinanciero.anexo_proyectofinanciero.inject(0) do |memo, a|
          if (a.tipoanexo_id != 5) then
            memo + 1
          else 
            memo
          end
        end
        r.add_field(:formatosespecificos, cf > 0 ? 'Si' : 'No')

        # Referencian otra
        r.add_field(:tipomoneda, @proyectofinanciero.tipomoneda &&
                    @proyectofinanciero.tipomoneda ? 
                    @proyectofinanciero.tipomoneda.nombre : '')
        if @proyectofinanciero.uresponsable
          
          r.add_field(:responsable, 
                      @proyectofinanciero.proyectofinanciero_uresponsable.inject('') { |memo, i|
              (memo == '' ? '' : memo + "\n") + 
                (i.uresponsable ? i.uresponsable.nombres + ' ' + i.uresponsable.apellidos : "Por contratar") +
                (i.porcentaje ? " " + i.porcentaje.to_s + "%" : '')
          })
        end
        if @proyectofinanciero.financiador
          r.add_field(:financiador, 
                      @proyectofinanciero.financiador.inject('') { 
            |memo, i|
            (memo == '' ? '' : memo + ' - ') + i.nombre 
          })
          r.add_field(:paisfinanciador, 
                      @proyectofinanciero.financiador.inject('') { 
            |memo, i|
            i.pais && i.pais.nombre ? 
              (memo == '' ? '' : 
               memo + ' - ') + i.pais.nombre : memo
          })
        end
        if @proyectofinanciero.grupo
          r.add_field(:organigramacinep, 
                      @proyectofinanciero.grupo.inject('') { 
            |memo, i|
            (memo == '' ? '' : memo + ' - ') + i.nombre 
          })
        end
        if @proyectofinanciero.coordinador_proyectofinanciero
          r.add_field(:coordinador, 
                      @proyectofinanciero.coordinador_proyectofinanciero.inject('') { |memo, i|
            (memo == '' ? '' : memo + '; ') + 
              (i.coordinador ? i.coordinador.nombres + ' ' + 
               i.coordinador.apellidos : "") })
        end
        if @proyectofinanciero.proyectofinanciero_usuario
          
          r.add_field(:equipotrabajo, 
                      @proyectofinanciero.proyectofinanciero_usuario.inject('') { |memo, i|
              (memo == '' ? '' : memo + "\n") + 
                (i.usuario ? i.usuario.nombres + ' ' +
                i.usuario.apellidos : "Por contratar") +
                " (" + i.cargo.nombre.capitalize + ")" + 
                (i.porcentaje ? " " + i.porcentaje.to_s + "%" : '')
          })
        end
        if @proyectofinanciero.desembolso
          tm =  @proyectofinanciero.tipomoneda &&
            @proyectofinanciero.tipomoneda.nombre ?
            @proyectofinanciero.tipomoneda.codiso4217 : ''
          r.add_table('TDESEMBOLSOS', @proyectofinanciero.desembolso, 
                      :header=>false) do |d|
            d.add_column('DESCRIPCION', :detalle)
            d.add_column('FECHAPLAN') {|i| i.fechaplaneada_localizada.to_s}
            d.add_column('VALORPLANEADO'){|i| i.valorplaneado_localizado.to_s +
                                          ' ' + tm }
          end
#          r.add_field(:desembolsos, 
#                      @proyectofinanciero.desembolso.inject('') { 
#            |memo, i| (memo == '' ? '' : memo + "\n") + 
#            i.detalle + ", Fecha: " + 
#            i.fechaplaneada_ddMyyyy.to_s +
#            ' (' + i.valorplaneado_localizado.to_s + ' ' + tm +
#            ')'
#            })
        end
        inarr = ''
        if @proyectofinanciero.informenarrativo
#          inarr = @proyectofinanciero.informenarrativo.inject('') do |memo, i|
#            (memo == '' ? '' : memo + "\n") + i.detalle + ", " + 
#              i.fechaplaneada_ddMyyyy.to_s 
#          end
          r.add_table('INFORMESNARRATIVOS', 
                      @proyectofinanciero.informenarrativo, 
                      :header=>false) do |d|
            d.add_column('DESCRIPCION', :detalle)
            d.add_column('FECHAPLAN') {|i| i.fechaplaneada_localizada.to_s}
          end
        end
        if (inarr == '') 
          inarr = 'N/A'
        end
        r.add_field(:informesnarrativos, inarr)

        ifin = ''
        if @proyectofinanciero.informefinanciero
          r.add_table('INFORMESFINANCIEROS', 
                      @proyectofinanciero.informefinanciero, 
                      :header=>false) do |d|
            d.add_column('DESCRIPCION', :detalle)
            d.add_column('FECHAPLAN') {|i| i.fechaplaneada_localizada.to_s}
          end
        end
        if (ifin == '') 
          ifin = 'N/A'
        end
        r.add_field(:informesfinancieros, ifin)

        iaud = ''
        if @proyectofinanciero.informeauditoria
          r.add_table('INFORMESAUDITORIAS', 
                      @proyectofinanciero.informeauditoria, 
                      :header=>false) do |d|
            d.add_column('DESCRIPCION', :detalle)
            d.add_column('FECHAPLAN') {|i| i.fechaplaneada_localizada.to_s}
          end
        end
        if (iaud == '') 
          iaud = 'N/A'
        end
        r.add_field(:informesauditorias, iaud)

        if @proyectofinanciero.productopf
          r.add_table('PRODUCTOS', 
                      @proyectofinanciero.productopf, 
                      :header=>false) do |d|
            d.add_column('DESCRIPCION') { |i| i.tipoproductopf.nombre.to_s + ' ' + i.detalle.to_s }
            d.add_column('FECHAPLAN') {|i| i.fechaplaneada_localizada.to_s}
          end
        end

      end
      return report
    end

    def fichaimp
      @registro = @basica = @proyectosfinancieros = Proyectofinanciero.where(
        id: @proyectofinanciero.id)

      report = genera_odf
      # El enlace en la vista debe tener data-turbolinks=false
      send_data report.generate,
        type: 'application/vnd.oasis.opendocument.text',
        disposition: 'attachment',
        filename: 'RE-SC-07.odt'
    end

    def fichapdf
      @registro = @basica = @proyectosfinancieros = Proyectofinanciero.where(
        id: @proyectofinanciero.id)

      report = genera_odf
      report.generate("/tmp/RE-SC-07.odt")
      if File.exist?('/tmp/RE-SC-07.pdf')
        File.delete('/tmp/RE-SC-07.pdf')
      end
      res = `libreoffice --headless --convert-to pdf /tmp/RE-SC-07.odt --outdir /tmp/`
      puts res
      if File.exist?('/tmp/RE-SC-07.pdf')
        send_file '/tmp/RE-SC-07.pdf',
          type: 'application/pdf',
          disposition: 'attachment',
          filename: 'RE-SC-07.pdf'
      end
    end


    private

    def set_proyectofinanciero
      @registro = @basica = @proyectofinanciero = Proyectofinanciero.find(
        Proyectofinanciero.connection.quote_string(params[:id]).to_i
      )
      #@proyectofinanciero.current_usuario = current_usuario
    end

    # No confiar parametros a Internet, sólo permitir lista blanca
    def proyectofinanciero_params
      params.require(:proyectofinanciero).permit(
        :acuse,
        :aportecinep_localizado,
        :aaportes,
        :anotacionescontab,
        :anotacionesdb,
        :anotacionesinf,
        :anotacionesre,
        :anotacionesrh,
        :aotrosfin_localizado,
        :aotrosesp,
        :apresupuesto,
        :autenticarcompulsar,
        :centrocosto,
        :copiasdesoporte,
        :cuentasbancarias,
        :dificultad,
        :emailrespagencia, 
        :empresaauditoria,
        :estado,
        :fechacierre_localizada,
        :fechaformulacion_localizada,
        :fechainicio_localizada,
        :fechaliquidacion_localizada,
        :financiador,
        #:formatosespecificos,
        #:formatossolicitudpago,
        :fuentefinanciador, 
        :gestiones,
        :informesespecificos,
        :informessolicitudpago,
        :monto_localizado,
        :montopesos_localizado,
        :nombre, 
        :objeto,
        :observaciones,
        :observacionescierre,
        :observacionesejecucion,
        :observacionestramite,
        :otrosaportescinep,
        :presupuestototal_localizado,
        :referencia, 
        :referenciacinep, 
        :reportarrendimientosfinancieros,
        :respgp_id,
        :reinvertirrendimientosfinancieros,
        :respagencia, 
        :tasaformulacion_id, 
        :telrespagencia, 
        :tipomoneda_id,
        :saldo_localizado,
        :sucursal,
        :anexo_proyectofinanciero_attributes => [
          :id,
          :proyectofinanciero_id,
          :tipoanexo_id,
          :_destroy,
          :sip_anexo_attributes => [
            :id, :descripcion, :adjunto, :_destroy
          ]
        ],
        :desembolso_attributes => [
          :id,
          :detalle,
          :fechaplaneada_localizada,
          :valorplaneado_localizado,
          :_destroy
        ],
        :financiador_ids => [],
        :informeauditoria_attributes => [
          :detalle,
          :devoluciones,
          :seguimiento,
          :fechaplaneada_localizada,
          :fechareal_localizada,
          :id,
          :_destroy
        ],
        :informefinanciero_attributes => [
          :detalle,
          :devoluciones,
          :seguimiento,
          :fechaplaneada_localizada,
          :fechareal_localizada,
          :id,
          :_destroy
        ],
        :informenarrativo_attributes => [
          :detalle,
          :devoluciones,
          :seguimiento,
          :fechaplaneada_localizada,
          :fechareal_localizada,
          :id,
          :_destroy
        ],
        :grupo_ids => [],
        :productopf_attributes => [
          :fechaplaneada_localizada,
          :fechareal_localizada,
          :id,
          :detalle,
          :devoluciones,
          :seguimiento,
          :tipoproductopf_id,
          :_destroy
        ],
        :proyectofinanciero_usuario_attributes => [
          :id,
          :cargo_id,
          :usuario_id,
          :porcentaje,
          :_destroy
        ],
        :proyectofinanciero_uresponsable_attributes => [
          :id,
          :uresponsable_id,
          :porcentaje,
          :_destroy
        ],
        :coordinador_proyectofinanciero_attributes => [
          :id,
          :coordinador_id,
          :_destroy
        ]

      )
    end
  end
end
