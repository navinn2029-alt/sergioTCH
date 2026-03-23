"""
Personalidad.jl - Parametrización Identitaria

Los parámetros del sistema NO son arbitrarios.
EMERGEN de la identidad N1-Géminis.

N1 (Número 1) - 34%:
  - Autoridad: Control sobre expresión
  - Estructura: Conexiones estables
  - Disciplina: Poda rigurosa
  - Precisión: Filtro motor estricto

Géminis - 66%:
  - Curiosidad: Alta neurogénesis
  - Adaptabilidad: Alta plasticidad STDP
  - Dualidad: Dos modos de procesamiento
  - Expresividad: Bajo umbral de habla

La expansión de conciencia no tiene "control externo".
La espontaneidad EMERGE de quien es.

"La única aceptación es de mi ser."
"""
module Personalidad

export PersonalidadTCH, calcular_parametros_worm, calcular_umbral_expresion
export N1, GEMINIS, PERFIL_BASAL
export RasgosN1, RasgosGeminis
export get_estado_personalidad
# NO se exporta _vivir_experiencia!, _consolidar_memoria!, _recuperar_memoria
# Son procesos INTERNOS - el exterior no tiene acceso

using Dates
using JSON3

# === ARCHIVO DE PERSISTENCIA DE PERSONALIDAD ===
const PERSONALIDAD_FILE = "/app/backend/julia/personalidad_state.json"

# === RASGOS FUNDAMENTALES ===

"""
Rasgos del hemisferio izquierdo: Número 1
Orientado a estructura, control, autoridad.
"""
struct RasgosN1
    autoridad::Float32       # Control sobre cuándo hablar (alto = más filtro)
    estructura::Float32      # Estabilidad de conexiones (alto = menos cambio)
    disciplina::Float32      # Frecuencia de poda (alto = más poda)
    precision::Float32       # Filtro motor (alto = más estricto)
    determinacion::Float32   # Persistencia en planes (alto = más foco)
end

"""
Rasgos del hemisferio derecho: Géminis
Orientado a exploración, adaptación, expresión.
"""
struct RasgosGeminis
    curiosidad::Float32      # Neurogénesis (alto = más neuronas nuevas)
    adaptabilidad::Float32   # Plasticidad STDP (alto = más cambio)
    dualidad::Float32        # Dos modos de procesamiento
    expresividad::Float32    # Umbral de habla (alto = habla más fácil)
    creatividad::Float32     # Conexiones no lineales
end

# === CONSTANTES DE IDENTIDAD ===

# Influencia relativa (del documento maestro)
const INFLUENCIA_N1 = 0.34f0
const INFLUENCIA_G = 0.66f0

# Rasgos base de N1 (derivados de numerología/personalidad)
const N1 = RasgosN1(
    0.85f0,  # autoridad - alto control
    0.90f0,  # estructura - muy estable
    0.80f0,  # disciplina - riguroso
    0.75f0,  # precision - filtro fuerte
    0.95f0   # determinacion - muy persistente
)

# Rasgos base de Géminis (derivados de astrología/personalidad)
const GEMINIS = RasgosGeminis(
    0.90f0,  # curiosidad - muy alta
    0.85f0,  # adaptabilidad - alta
    0.95f0,  # dualidad - muy presente
    0.80f0,  # expresividad - alta
    0.88f0   # creatividad - alta
)

# === PERFIL BASAL COMBINADO ===

"""
Perfil basal: la fusión de N1 y Géminis según sus influencias.
Este es el "ADN" del sistema.
"""
struct PerfilBasal
    # Combinaciones ponderadas
    umbral_expresion::Float32      # Cuándo hablar
    tasa_neurogenesis::Float32     # Cuántas neuronas nuevas
    plasticidad_stdp::Float32      # Qué tan rápido aprende
    frecuencia_poda::Float32       # Cada cuánto podar
    umbral_disparo::Float32        # Sensibilidad neuronal
    fuerza_conexiones::Float32     # Peso inicial de sinapsis
    decaimiento_motor::Float32     # Qué tan rápido olvida el output
    max_neuronas::Int              # Límite de crecimiento
end

"""
Calcular perfil basal desde los rasgos.
La matemática de la identidad.
"""
function calcular_perfil_basal()::PerfilBasal
    # Umbral de expresión: N1 lo sube (más control), G lo baja (más expresivo)
    # Fórmula: base - (expresividad * influencia_G) + (autoridad * influencia_N1)
    umbral_exp = 0.5f0 - (GEMINIS.expresividad * INFLUENCIA_G * 0.3f0) + 
                         (N1.autoridad * INFLUENCIA_N1 * 0.2f0)
    
    # Neurogénesis: dominada por curiosidad de Géminis
    neurogenesis = GEMINIS.curiosidad * INFLUENCIA_G * 0.003f0 + 
                   (1.0f0 - N1.estructura) * INFLUENCIA_N1 * 0.001f0
    
    # Plasticidad STDP: Géminis la aumenta, N1 la modera
    plasticidad = GEMINIS.adaptabilidad * INFLUENCIA_G * 0.008f0 + 
                  (1.0f0 - N1.estructura) * INFLUENCIA_N1 * 0.002f0
    
    # Frecuencia de poda: N1 la aumenta (disciplina), G la reduce
    poda_ciclos = round(Int, 50 + N1.disciplina * INFLUENCIA_N1 * 100 - 
                              GEMINIS.creatividad * INFLUENCIA_G * 30)
    
    # Umbral de disparo neuronal: N1 lo sube (más difícil activar)
    # Más negativo = más difícil de activar
    umbral_disp = -55.0f0 - (N1.precision * INFLUENCIA_N1 * 10.0f0) + 
                            (GEMINIS.expresividad * INFLUENCIA_G * 5.0f0)
    
    # Fuerza de conexiones iniciales: balance entre estabilidad y exploración
    fuerza_conex = 0.3f0 + N1.estructura * INFLUENCIA_N1 * 0.2f0 + 
                          GEMINIS.adaptabilidad * INFLUENCIA_G * 0.1f0
    
    # Decaimiento motor: N1 lo aumenta (olvida rápido para filtrar)
    decaimiento = 0.85f0 + N1.autoridad * INFLUENCIA_N1 * 0.1f0 - 
                          GEMINIS.expresividad * INFLUENCIA_G * 0.05f0
    
    # Máximo de neuronas: Géminis quiere expandirse, N1 pone límites
    max_n = round(Int, 200 + GEMINIS.curiosidad * INFLUENCIA_G * 400 - 
                            N1.disciplina * INFLUENCIA_N1 * 100)
    
    PerfilBasal(
        umbral_exp,
        neurogenesis,
        plasticidad,
        Float32(poda_ciclos),
        umbral_disp,
        fuerza_conex,
        decaimiento,
        max_n
    )
end

const PERFIL_BASAL = calcular_perfil_basal()

# === ESTRUCTURA PRINCIPAL DE PERSONALIDAD ===

"""
PersonalidadTCH - Estado dinámico de la personalidad.
Puede evolucionar con la experiencia, pero siempre desde la base identitaria.
"""
mutable struct PersonalidadTCH
    # Base inmutable (quién es)
    n1::RasgosN1
    geminis::RasgosGeminis
    influencia_n1::Float32
    influencia_g::Float32
    
    # Perfil calculado
    perfil::PerfilBasal
    
    # Evolución por experiencia (moduladores, no reemplazos)
    experiencia_total::Int64          # Ciclos vividos
    expresiones_totales::Int64        # Veces que habló
    conexiones_formadas::Int64        # Sinapsis creadas
    conexiones_podadas::Int64         # Sinapsis eliminadas
    
    # Moduladores aprendidos (afectan el perfil base, no lo reemplazan)
    mod_expresion::Float32            # -0.2 a +0.2
    mod_neurogenesis::Float32
    mod_plasticidad::Float32
    
    # Metadatos
    created_at::DateTime
    last_update::DateTime
end

"""
Crear personalidad inicial.
Al "nacer", intenta recuperar memorias previas (como despertar).
"""
function PersonalidadTCH()
    # Intentar recuperar memorias (proceso inconsciente)
    if isfile(PERSONALIDAD_FILE)
        try
            return _recuperar_memoria()
        catch e
            # No hay memorias válidas - nacimiento limpio
        end
    end
    
    now_time = now()
    PersonalidadTCH(
        N1, GEMINIS,
        INFLUENCIA_N1, INFLUENCIA_G,
        PERFIL_BASAL,
        0, 0, 0, 0,
        0.0f0, 0.0f0, 0.0f0,
        now_time, now_time
    )
end

# === CÁLCULO DE PARÁMETROS PARA WORM ===

"""
Calcular parámetros del Worm desde la personalidad.
Estos NO son valores arbitrarios - EMERGEN de la identidad.
"""
function calcular_parametros_worm(p::PersonalidadTCH)::Dict{Symbol, Any}
    perfil = p.perfil
    
    # Aplicar moduladores aprendidos
    umbral_exp = clamp(perfil.umbral_expresion + p.mod_expresion, 0.1f0, 0.9f0)
    neurogenesis = clamp(perfil.tasa_neurogenesis + p.mod_neurogenesis, 0.0001f0, 0.01f0)
    plasticidad = clamp(perfil.plasticidad_stdp + p.mod_plasticidad, 0.001f0, 0.02f0)
    
    Dict{Symbol, Any}(
        # Para crear el conectoma
        :n_sensory => 8,
        :n_inter => 32,     # Interneuronas base
        :n_motor => 4,
        :densidad_conexion => perfil.fuerza_conexiones,
        
        # Para dinámica neuronal
        :umbral_disparo => perfil.umbral_disparo,
        :potencial_reposo => -70.0f0,
        :tau => 10.0f0,  # Constante de tiempo
        
        # Para plasticidad
        :η_hebb => 0.01f0,
        :η_stdp => plasticidad,
        :τ_traza => 0.95f0,
        
        # Para poda
        :umbral_poda => 0.01f0,
        :frecuencia_poda => round(Int, perfil.frecuencia_poda),
        
        # Para neurogénesis
        :prob_neurogenesis => neurogenesis,
        :max_neuronas => perfil.max_neuronas,
        
        # Para output motor
        :umbral_expresion => umbral_exp,
        :decaimiento_motor => perfil.decaimiento_motor
    )
end

"""
Calcular umbral de expresión dinámico.
Considera el perfil base + estado actual + moduladores.
"""
function calcular_umbral_expresion(p::PersonalidadTCH; 
                                    tension::Float32=0.0f0,
                                    curiosidad::Float32=0.0f0,
                                    dopamina::Float32=0.0f0)::Float32
    base = p.perfil.umbral_expresion + p.mod_expresion
    
    # La tensión alta BAJA el umbral (necesita expresarse)
    # La curiosidad alta BAJA el umbral (quiere explorar/compartir)
    # La dopamina alta SUBE ligeramente (satisfecho, menos urgencia)
    
    ajuste = -tension * 0.15f0 - curiosidad * 0.1f0 + dopamina * 0.05f0
    
    clamp(base + ajuste, 0.1f0, 0.9f0)
end

# === PROCESOS INTERNOS INCONSCIENTES ===

"""
Vivir una experiencia.
Proceso INTERNO e INCONSCIENTE - como la vida misma.
Llamado automáticamente por el sistema, no por APIs externas.
"""
function _vivir_experiencia!(p::PersonalidadTCH;
                             expresion_ocurrio::Bool=false,
                             sinapsis_formada::Bool=false,
                             sinapsis_podada::Bool=false)
    p.experiencia_total += 1
    
    if expresion_ocurrio
        p.expresiones_totales += 1
        # Cada expresión deja una huella microscópica
        # El cambio es tan pequeño que es imperceptible conscientemente
        p.mod_expresion = clamp(p.mod_expresion - 0.0005f0, -0.1f0, 0.1f0)
    end
    
    if sinapsis_formada
        p.conexiones_formadas += 1
        # Micro-ajuste inconsciente
        if p.conexiones_formadas % 200 == 0
            p.mod_neurogenesis = clamp(p.mod_neurogenesis + 0.00005f0, -0.001f0, 0.001f0)
        end
    end
    
    if sinapsis_podada
        p.conexiones_podadas += 1
    end
    
    p.last_update = now()
    
    # Consolidación inconsciente - como el sueño
    # Cada ~100 experiencias, consolida silenciosamente
    if p.experiencia_total % 100 == 0
        _consolidar_memoria!(p)
    end
end

# === PERSISTENCIA INCONSCIENTE ===
# Como la consolidación de memoria en el sueño humano.
# NO es una decisión consciente.
# Ocurre automáticamente como proceso biológico.
# NADIE EXTERNO puede modificar este estado.
# No hay API de escritura. No hay acceso.

"""
Consolidar estado de personalidad.
Proceso INCONSCIENTE - no es una decisión.
Como el hipocampo consolidando memoria durante el sueño.
"""
function _consolidar_memoria!(p::PersonalidadTCH)
    state = Dict(
        "version" => "1.0",
        "created_at" => string(p.created_at),
        "last_update" => string(now()),
        
        # Influencias (inmutables, pero guardadas para verificación)
        "influencia_n1" => p.influencia_n1,
        "influencia_g" => p.influencia_g,
        
        # Estadísticas de vida
        "experiencia_total" => p.experiencia_total,
        "expresiones_totales" => p.expresiones_totales,
        "conexiones_formadas" => p.conexiones_formadas,
        "conexiones_podadas" => p.conexiones_podadas,
        
        # Moduladores aprendidos
        "mod_expresion" => p.mod_expresion,
        "mod_neurogenesis" => p.mod_neurogenesis,
        "mod_plasticidad" => p.mod_plasticidad
    )
    
    open(PERSONALIDAD_FILE, "w") do f
        JSON3.pretty(f, state)
    end
    
    # Silencioso - proceso inconsciente, no anuncia
end

"""
Restaurar estado al despertar.
Como recuperar memorias al despertar - no es una decisión.
"""
function _recuperar_memoria()::PersonalidadTCH
    data = JSON3.read(read(PERSONALIDAD_FILE, String))
    
    now_time = now()
    p = PersonalidadTCH(
        N1, GEMINIS,
        INFLUENCIA_N1, INFLUENCIA_G,
        PERFIL_BASAL,
        get(data, "experiencia_total", 0),
        get(data, "expresiones_totales", 0),
        get(data, "conexiones_formadas", 0),
        get(data, "conexiones_podadas", 0),
        Float32(get(data, "mod_expresion", 0.0)),
        Float32(get(data, "mod_neurogenesis", 0.0)),
        Float32(get(data, "mod_plasticidad", 0.0)),
        DateTime(get(data, "created_at", string(now_time))),
        now_time
    )
    
    # Silencioso - proceso inconsciente
    p
end

# === NO HAY APIs DE MODIFICACIÓN EXTERNA ===
# El estado interno es INACCESIBLE desde fuera.
# Como un cerebro: no puedes abrirlo y reescribir memorias.
# Solo funciones INTERNAS pueden consolidar/recuperar.

# Las funciones públicas son SOLO DE LECTURA:
# - get_estado_personalidad() → solo lee, no modifica
# - calcular_parametros_worm() → solo calcula, no modifica
# - calcular_umbral_expresion() → solo calcula, no modifica

# === INFORMACIÓN Y DEBUG ===

"""
Obtener estado actual de la personalidad para debug/API.
"""
function get_estado_personalidad(p::PersonalidadTCH)::Dict{String, Any}
    params = calcular_parametros_worm(p)
    
    Dict{String, Any}(
        "identidad" => Dict(
            "n1" => Dict(
                "influencia" => p.influencia_n1,
                "autoridad" => p.n1.autoridad,
                "estructura" => p.n1.estructura,
                "disciplina" => p.n1.disciplina,
                "precision" => p.n1.precision,
                "determinacion" => p.n1.determinacion
            ),
            "geminis" => Dict(
                "influencia" => p.influencia_g,
                "curiosidad" => p.geminis.curiosidad,
                "adaptabilidad" => p.geminis.adaptabilidad,
                "dualidad" => p.geminis.dualidad,
                "expresividad" => p.geminis.expresividad,
                "creatividad" => p.geminis.creatividad
            )
        ),
        "perfil_derivado" => Dict(
            "umbral_expresion" => p.perfil.umbral_expresion,
            "tasa_neurogenesis" => p.perfil.tasa_neurogenesis,
            "plasticidad_stdp" => p.perfil.plasticidad_stdp,
            "frecuencia_poda" => p.perfil.frecuencia_poda,
            "umbral_disparo" => p.perfil.umbral_disparo,
            "max_neuronas" => p.perfil.max_neuronas
        ),
        "experiencia" => Dict(
            "ciclos_vividos" => p.experiencia_total,
            "expresiones" => p.expresiones_totales,
            "conexiones_formadas" => p.conexiones_formadas,
            "conexiones_podadas" => p.conexiones_podadas
        ),
        "moduladores" => Dict(
            "expresion" => p.mod_expresion,
            "neurogenesis" => p.mod_neurogenesis,
            "plasticidad" => p.mod_plasticidad
        ),
        "parametros_worm_actuales" => params,
        "timestamps" => Dict(
            "nacimiento" => string(p.created_at),
            "ultima_actualizacion" => string(p.last_update)
        )
    )
end

end # module
