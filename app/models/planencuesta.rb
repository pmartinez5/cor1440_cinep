# encoding: UTF-8

class Planencuesta < ActiveRecord::Base
	include Sip::Modelo
  include Sip::Localizacion

  belongs_to :formulario, class_name: 'Mr519Gen::Formulario',
    foreign_key: :formulario_id
  belongs_to :plantillacorreoinv, class_name: '::Plantillacorreo',
    foreign_key: :plantillacorreoinv_id

  has_many :encuestapersona, dependent: :destroy,
    class_name: 'Mr519Gen::Encuestapersona',
    foreign_key: 'planencuesta_id'
  accepts_nested_attributes_for :encuestapersona, 
    allow_destroy: true, reject_if: :all_blank
  has_many :persona, through: :encuestapersona,
    class_name: 'Sip::Persona'

  campofecha_localizado :fechaini
  campofecha_localizado :fechafin

  validate :fechas_ordenadas
  def fechas_ordenadas
    if fechaini && fechafin && fechaini > fechafin
      errors.add(:fechafin, 
                 "La fecha de terminación debe ser posterior a la de inicio")
    end
  end

  def presenta_nombre
    self.formulario_id ?  self.formulario.nombre + " (#{id})" : "#{id}"
  end
end
