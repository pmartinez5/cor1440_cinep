# encoding: utf-8

module Cor1440Gen
  class Pmindicadorpf < ActiveRecord::Base
    include Sip::Modelo
    include Sip::Localizacion

    campofecha_localizado :fecha
    campofecha_localizado :finicio
    campofecha_localizado :ffin

    validates :urlev1, length: {maximum: 1024}
    validates :urlev2, length: {maximum: 1024}
    validates :urlev3, length: {maximum: 1024}
    validates :urlevrind, length: {maximum: 1024}

    belongs_to :cor1440_gen_mindicadorpf, 
      class_name: 'Cor1440Gen::Mindicadorpf', 
      foreign_key: 'mindicadorpf_id'

  end
end
