# encoding: UTF-8
require_dependency "cor1440_gen/concerns/controllers/actividades_controller"

module Cor1440Gen
  class ActividadesController < ApplicationController
    include Cor1440Gen::Concerns::Controllers::ActividadesController


    def filtra
      ac = Actividad.order(fecha: :desc)
      w = ""
      @buscodigo = param_escapa('buscodigo')
      if @buscodigo != '' then
        ac = ac.where(id: @buscodigo.to_i)
      end
      @fechaini = param_escapa('fechaini')
      if @fechaini != '' then
        ac = ac.where("fecha >= '#{@fechaini}'")
      end
      @fechafin = param_escapa('fechafin')
      if @fechafin != '' then
        ac = ac.where("fecha <= '#{@fechafin}'")
      end
      @busresponsable = param_escapa('busresponsable')
      if @busresponsable != '' then
        ac = ac.where(responsable: @busresponsable)
      end
      @busnombre = param_escapa('busnombre')
      if @busnombre != '' then
        ac = ac.where("nombre ILIKE '%#{@busnombre}%'")
      end
      @busarea = param_escapa('busarea')
      if @busarea != '' then
        ac = ac.joins(:actividadareas_actividad).where(
          "cor1440_gen_actividadareas_actividad.actividadarea_id = ?",
          @busarea.to_i
        )
      end
      @bustipo = param_escapa('bustipo')
      if @bustipo != '' then
        ac = ac.joins(:actividad_actividadtipo).where(
          "cor1440_gen_actividad_actividadtipo.actividadtipo_id = ?",
          @bustipo.to_i
        )
      end
      @busobjetivo = param_escapa('busobjetivo')
      if @busobjetivo != '' then
        ac = ac.where("objetivo ILIKE '%#{@busobjetivo}%'")
      end
      @busproyecto = param_escapa('busproyecto')
      if @busproyecto != '' then
        ac = ac.joins(:actividad_proyecto).where(
          "cor1440_gen_actividad_proyecto.proyecto_id= ?",
          @busproyecto.to_i
        )
      end
      @busresultado = param_escapa('busresultado')
      if @busresultado != '' then
        ac = ac.where("resultado ILIKE '%#{@busresultado}%'")
      end
      return ac
    end

    # Encabezado comun para HTML y PDF (primeras filas)
    def encabezado_comun
      return [ Cor1440Gen::Actividad.human_attribute_name(:id), 
        @actividades.human_attribute_name(:fecha),
        @actividades.human_attribute_name(:responsable),
        @actividades.human_attribute_name(:nombre),
        @actividades.human_attribute_name(:areas),
        @actividades.human_attribute_name(:tipos),
        @actividades.human_attribute_name(:objetivo),
        @actividades.human_attribute_name(:proyectos),
        @actividades.human_attribute_name(:resultado)
      ]
    end

    def fila_comun(actividad)
      return [actividad.id,
        actividad.fecha , 
        actividad.responsable ? actividad.responsable.nusuario : "",
        actividad.nombre ? actividad.nombre : "",
        actividad.actividadareas.inject("") { |memo, i| 
          (memo == "" ? "" : memo + "; ") + i.nombre 
        },
          actividad.actividadtipo.inject("") { |memo, i| 
          (memo == "" ? "" : memo + "; ") + i.nombre 
        },
          actividad.objetivo , 
          actividad.proyecto.inject("") { |memo, i| 
          (memo == "" ? "" : memo + "; ") + i.nombre 
        },
          actividad.resultado
      ]
    end

    # No confiar parametros a Internet, sólo permitir lista blanca
    def actividad_params
      params.require(:actividad).permit(
        :oficina_id, :minutos, :nombre, 
        :objetivo, :proyecto, :resultado,
        :fecha, :actividad, :observaciones, 
        :usuario_id,
        :lugar, 
        :convocante, 
        :participantes, 
        :totorg, 
        :mujeres, 
        :hombres, 
        :negros, 
        :indigenas, 
        :mestizos, 
        :blancos, 
        :desarrollo, 
        :valora,
        :actividadarea_ids => [],
        :actividadtipo_ids => [],
        :proyecto_ids => [],
        :actividad_rangoedadac_attributes => [
          :id, :rangoedadac_id, :fl, :fr, :ml, :mr, :_destroy
      ],
        :actividad_sip_anexo_attributes => [
          :id,
          :id_actividad, 
          :_destroy,
          :sip_anexo_attributes => [
            :id, :descripcion, :adjunto, :_destroy
      ]
      ]
      )
    end
  end
end
