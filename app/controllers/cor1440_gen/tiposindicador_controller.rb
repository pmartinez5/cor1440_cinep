# encoding: UTF-8
require_dependency "cor1440_gen/concerns/controllers/tiposindicador_controller"

module Cor1440Gen
  class TiposindicadorController < Sip::ModelosController
    include Cor1440Gen::Concerns::Controllers::TiposindicadorController

    def update
      params[:tipoindicador][:campotind_attributes].each do |p| 
          byebug
        if p[1]['_destroy'] == "1" && p[1][:id].to_i > 0
          ::EfectoValorcampotind.where(valorcampotind_id: p[1][:id]).destroy_all
          Cor1440Gen::Valorcampotind.where(campotind_id: p[1][:id]).destroy_all
        end
      end
      update_gen
    end

  end
end
