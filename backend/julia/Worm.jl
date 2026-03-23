"""
Worm.jl - Conectoma Dinámico Inspirado en C. elegans

Un sistema nervioso vivo donde:
- Las neuronas nacen (neurogénesis)
- Las conexiones se fortalecen o debilitan (plasticidad)
- Las conexiones débiles mueren (poda sináptica)

302 neuronas en C. elegans. Aquí empezamos pequeño y crecemos.
"""
module Worm

using Random
using Dates

export Neuron, Synapse, Connectome
export create_connectome, tick!, stimulate!, get_output
export prune!, neurogenesis!, get_stats
export NeuronType, SENSORY, INTER, MOTOR

# === TIPOS DE NEURONAS ===
@enum NeuronType begin
    SENSORY = 1   # Reciben input del exterior (oído, piel)
    INTER = 2     # Procesan (pensamiento)
    MOTOR = 3     # Generan output (voz, acción)
end

# === NEURONA ===
mutable struct Neuron
    id::Int
    tipo::NeuronType
    
    # Estado eléctrico
    potencial::Float32          # Potencial de membrana actual
    umbral::Float32             # Umbral de disparo
    potencial_reposo::Float32   # Potencial en reposo
    
    # Dinámica temporal
    tau::Float32                # Constante de tiempo (decaimiento)
    refractario::Int            # Ciclos restantes en periodo refractario
    periodo_refractario::Int    # Duración del periodo refractario
    
    # Historia
    disparos::Int               # Total de veces que ha disparado
    ultimo_disparo::Int         # Ciclo del último disparo
    edad::Int                   # Ciclos desde que nació
    
    # Metadatos
    nombre::String
    nacimiento::DateTime
end

# === SINAPSIS ===
mutable struct Synapse
    id::Int
    pre::Int                    # ID neurona presináptica
    post::Int                   # ID neurona postsináptica
    
    peso::Float32               # Fuerza de la conexión [-1, 1]
    tipo::Symbol                # :excitadora o :inhibidora
    
    # Plasticidad
    activaciones::Int           # Veces que se ha activado
    ultima_activacion::Int      # Ciclo de última activación
    edad::Int                   # Ciclos desde que se formó
    
    # Para STDP (Spike-Timing Dependent Plasticity)
    traza_pre::Float32          # Traza de actividad presináptica
    traza_post::Float32         # Traza de actividad postsináptica
end

# === CONECTOMA ===
mutable struct Connectome
    # Estructura
    neuronas::Dict{Int, Neuron}
    sinapsis::Dict{Int, Synapse}
    
    # Índices para búsqueda rápida
    sinapsis_por_pre::Dict{Int, Vector{Int}}   # pre_id -> [synapse_ids]
    sinapsis_por_post::Dict{Int, Vector{Int}}  # post_id -> [synapse_ids]
    
    # Contadores
    next_neuron_id::Int
    next_synapse_id::Int
    ciclo::Int
    
    # Parámetros de plasticidad
    η_hebb::Float32             # Tasa de aprendizaje Hebbiano
    η_stdp::Float32             # Tasa STDP
    τ_traza::Float32            # Decaimiento de trazas
    
    # Parámetros de poda
    umbral_poda::Float32        # Peso mínimo para sobrevivir
    frecuencia_poda::Int        # Cada cuántos ciclos podar
    
    # Parámetros de neurogénesis
    prob_neurogenesis::Float32  # Probabilidad de nueva neurona por ciclo
    max_neuronas::Int           # Límite de neuronas
    
    # Estado de salida
    output_buffer::Vector{Float32}
    
    # Lock para paralelismo
    lock::ReentrantLock
end

# === CONSTRUCTORES ===

function Neuron(id::Int, tipo::NeuronType; nombre::String="")
    Neuron(
        id, tipo,
        -70.0f0,        # potencial (mV típico de reposo)
        -55.0f0,        # umbral de disparo
        -70.0f0,        # potencial de reposo
        20.0f0,         # tau (ms)
        0,              # refractario
        3,              # periodo refractario
        0, 0, 0,        # disparos, ultimo_disparo, edad
        isempty(nombre) ? "N$id" : nombre,
        now()
    )
end

function Synapse(id::Int, pre::Int, post::Int; peso::Float32=0.1f0)
    tipo = peso >= 0 ? :excitadora : :inhibidora
    Synapse(
        id, pre, post,
        peso, tipo,
        0, 0, 0,        # activaciones, ultima_activacion, edad
        0.0f0, 0.0f0    # trazas
    )
end

"""
Crear un conectoma inicial con estructura básica.
Empieza pequeño: sensorial -> inter -> motor
"""
function create_connectome(;
    n_sensory::Int=8,
    n_inter::Int=16,
    n_motor::Int=4,
    densidad_conexion::Float32=0.3f0
)::Connectome
    
    neuronas = Dict{Int, Neuron}()
    sinapsis = Dict{Int, Synapse}()
    sinapsis_por_pre = Dict{Int, Vector{Int}}()
    sinapsis_por_post = Dict{Int, Vector{Int}}()
    
    neuron_id = 1
    synapse_id = 1
    
    # Crear neuronas sensoriales
    sensory_ids = Int[]
    for i in 1:n_sensory
        n = Neuron(neuron_id, SENSORY, nombre="S$i")
        neuronas[neuron_id] = n
        sinapsis_por_pre[neuron_id] = Int[]
        sinapsis_por_post[neuron_id] = Int[]
        push!(sensory_ids, neuron_id)
        neuron_id += 1
    end
    
    # Crear interneuronas
    inter_ids = Int[]
    for i in 1:n_inter
        n = Neuron(neuron_id, INTER, nombre="I$i")
        neuronas[neuron_id] = n
        sinapsis_por_pre[neuron_id] = Int[]
        sinapsis_por_post[neuron_id] = Int[]
        push!(inter_ids, neuron_id)
        neuron_id += 1
    end
    
    # Crear neuronas motoras
    motor_ids = Int[]
    for i in 1:n_motor
        n = Neuron(neuron_id, MOTOR, nombre="M$i")
        neuronas[neuron_id] = n
        sinapsis_por_pre[neuron_id] = Int[]
        sinapsis_por_post[neuron_id] = Int[]
        push!(motor_ids, neuron_id)
        neuron_id += 1
    end
    
    # Conectar sensorial -> inter (feedforward)
    for s_id in sensory_ids
        for i_id in inter_ids
            if rand() < densidad_conexion
                peso = (rand(Float32) * 0.4f0 + 0.1f0) * (rand() < 0.8 ? 1 : -1)
                syn = Synapse(synapse_id, s_id, i_id, peso=peso)
                sinapsis[synapse_id] = syn
                push!(sinapsis_por_pre[s_id], synapse_id)
                push!(sinapsis_por_post[i_id], synapse_id)
                synapse_id += 1
            end
        end
    end
    
    # Conectar inter -> inter (recurrente)
    for i1 in inter_ids
        for i2 in inter_ids
            if i1 != i2 && rand() < densidad_conexion * 0.5f0
                peso = (rand(Float32) * 0.3f0 + 0.05f0) * (rand() < 0.7 ? 1 : -1)
                syn = Synapse(synapse_id, i1, i2, peso=peso)
                sinapsis[synapse_id] = syn
                push!(sinapsis_por_pre[i1], synapse_id)
                push!(sinapsis_por_post[i2], synapse_id)
                synapse_id += 1
            end
        end
    end
    
    # Conectar inter -> motor
    for i_id in inter_ids
        for m_id in motor_ids
            if rand() < densidad_conexion
                peso = rand(Float32) * 0.5f0 + 0.1f0  # Solo excitadoras a motoras
                syn = Synapse(synapse_id, i_id, m_id, peso=peso)
                sinapsis[synapse_id] = syn
                push!(sinapsis_por_pre[i_id], synapse_id)
                push!(sinapsis_por_post[m_id], synapse_id)
                synapse_id += 1
            end
        end
    end
    
    Connectome(
        neuronas, sinapsis,
        sinapsis_por_pre, sinapsis_por_post,
        neuron_id, synapse_id, 0,
        0.01f0,         # η_hebb
        0.005f0,        # η_stdp
        0.95f0,         # τ_traza
        0.01f0,         # umbral_poda
        100,            # frecuencia_poda
        0.001f0,        # prob_neurogenesis
        500,            # max_neuronas
        zeros(Float32, n_motor),
        ReentrantLock()
    )
end

# === DINÁMICA NEURONAL ===

"""
Avanzar un ciclo del conectoma.
Retorna true si hubo actividad motora.
"""
function tick!(conn::Connectome)::Bool
    lock(conn.lock) do
        conn.ciclo += 1
        
        # 1. Actualizar edad de todo
        for (_, n) in conn.neuronas
            n.edad += 1
        end
        for (_, s) in conn.sinapsis
            s.edad += 1
        end
        
        # 2. Decaer trazas sinápticas
        for (_, syn) in conn.sinapsis
            syn.traza_pre *= conn.τ_traza
            syn.traza_post *= conn.τ_traza
        end
        
        # 3. Calcular input sináptico para cada neurona
        inputs = Dict{Int, Float32}()
        for (id, _) in conn.neuronas
            inputs[id] = 0.0f0
        end
        
        for (_, syn) in conn.sinapsis
            pre_n = conn.neuronas[syn.pre]
            # Si la presináptica disparó recientemente, transmitir
            if pre_n.ultimo_disparo == conn.ciclo - 1
                inputs[syn.post] += syn.peso
                syn.activaciones += 1
                syn.ultima_activacion = conn.ciclo
                syn.traza_pre = 1.0f0
            end
        end
        
        # 4. Actualizar potencial de cada neurona
        disparos = Int[]
        for (id, n) in conn.neuronas
            # Periodo refractario
            if n.refractario > 0
                n.refractario -= 1
                n.potencial = n.potencial_reposo
                continue
            end
            
            # Dinámica de membrana (leaky integrate-and-fire)
            # dV/dt = -(V - V_rest)/tau + I
            leak = (n.potencial - n.potencial_reposo) / n.tau
            n.potencial += -leak + inputs[id] * 10.0f0  # Escalar input
            
            # Disparo si supera umbral
            if n.potencial >= n.umbral
                push!(disparos, id)
                n.disparos += 1
                n.ultimo_disparo = conn.ciclo
                n.refractario = n.periodo_refractario
                n.potencial = n.potencial_reposo - 10.0f0  # Hiperpolarización
                
                # Actualizar traza postsináptica en sinapsis entrantes
                for syn_id in conn.sinapsis_por_post[id]
                    conn.sinapsis[syn_id].traza_post = 1.0f0
                end
            end
        end
        
        # 5. Plasticidad STDP
        apply_stdp!(conn, disparos)
        
        # 6. Actualizar output buffer (neuronas motoras)
        motor_activity = false
        for (id, n) in conn.neuronas
            if n.tipo == MOTOR
                idx = parse(Int, replace(n.nombre, "M" => ""))
                if idx <= length(conn.output_buffer)
                    # Actividad = potencial normalizado
                    activity = clamp((n.potencial - n.potencial_reposo) / 
                                    (n.umbral - n.potencial_reposo), 0.0f0, 1.0f0)
                    conn.output_buffer[idx] = activity
                    if activity > 0.5f0
                        motor_activity = true
                    end
                end
            end
        end
        
        # 7. Poda periódica
        if conn.ciclo % conn.frecuencia_poda == 0
            prune!(conn)
        end
        
        # 8. Neurogénesis ocasional
        if rand() < conn.prob_neurogenesis && length(conn.neuronas) < conn.max_neuronas
            neurogenesis!(conn)
        end
        
        motor_activity
    end
end

"""
Aplicar plasticidad STDP (Spike-Timing Dependent Plasticity).
Neuronas que disparan juntas, se conectan más fuerte.
"""
function apply_stdp!(conn::Connectome, disparos::Vector{Int})
    for (_, syn) in conn.sinapsis
        # Si ambas trazas están activas, fortalecer (LTP)
        if syn.traza_pre > 0.1f0 && syn.traza_post > 0.1f0
            Δw = conn.η_stdp * syn.traza_pre * syn.traza_post
            syn.peso = clamp(syn.peso + Δw, -1.0f0, 1.0f0)
        end
        
        # Si solo pre está activa pero post no, debilitar (LTD)
        if syn.traza_pre > 0.5f0 && syn.traza_post < 0.1f0
            Δw = -conn.η_stdp * 0.5f0 * syn.traza_pre
            syn.peso = clamp(syn.peso + Δw, -1.0f0, 1.0f0)
        end
    end
end

"""
Estimular neuronas sensoriales con input externo.
input: vector de valores [0, 1] para cada neurona sensorial
"""
function stimulate!(conn::Connectome, input::Vector{Float32})
    lock(conn.lock) do
        sensory_neurons = [n for (_, n) in conn.neuronas if n.tipo == SENSORY]
        sort!(sensory_neurons, by=n -> n.id)
        
        for (i, n) in enumerate(sensory_neurons)
            if i <= length(input)
                # Inyectar corriente proporcional al input
                n.potencial += input[i] * 30.0f0  # Escalar
            end
        end
    end
end

"""
Obtener output de las neuronas motoras.
"""
function get_output(conn::Connectome)::Vector{Float32}
    copy(conn.output_buffer)
end

# === PODA SINÁPTICA ===

"""
Eliminar conexiones débiles.
"Use it or lose it" - si una sinapsis no se usa, muere.
"""
function prune!(conn::Connectome)
    lock(conn.lock) do
        to_remove = Int[]
        
        for (id, syn) in conn.sinapsis
            # Criterios de poda:
            # 1. Peso muy bajo
            # 2. No se ha usado en mucho tiempo
            peso_debil = abs(syn.peso) < conn.umbral_poda
            inactiva = (conn.ciclo - syn.ultima_activacion) > 200 && syn.activaciones < 5
            
            if peso_debil || (inactiva && syn.edad > 50)
                push!(to_remove, id)
            end
        end
        
        # Eliminar sinapsis
        for id in to_remove
            syn = conn.sinapsis[id]
            
            # Remover de índices
            filter!(x -> x != id, conn.sinapsis_por_pre[syn.pre])
            filter!(x -> x != id, conn.sinapsis_por_post[syn.post])
            
            # Eliminar
            delete!(conn.sinapsis, id)
        end
        
        if !isempty(to_remove)
            # println("🔪 Poda: $(length(to_remove)) sinapsis eliminadas")
        end
        
        length(to_remove)
    end
end

# === NEUROGÉNESIS ===

"""
Crear una nueva neurona y conectarla a la red.
Las nuevas neuronas son siempre interneuronas (como en el hipocampo).
"""
function neurogenesis!(conn::Connectome)
    lock(conn.lock) do
        # Crear nueva interneurona
        id = conn.next_neuron_id
        conn.next_neuron_id += 1
        
        n = Neuron(id, INTER, nombre="I_new$(id)")
        # Las nuevas neuronas son más excitables inicialmente
        n.umbral = -58.0f0
        
        conn.neuronas[id] = n
        conn.sinapsis_por_pre[id] = Int[]
        conn.sinapsis_por_post[id] = Int[]
        
        # Conectar a neuronas activas (las que han disparado recientemente)
        active_neurons = [nid for (nid, neuron) in conn.neuronas 
                         if (conn.ciclo - neuron.ultimo_disparo) < 20 && nid != id]
        
        # Recibir conexiones de neuronas activas
        for pre_id in active_neurons[1:min(3, length(active_neurons))]
            syn_id = conn.next_synapse_id
            conn.next_synapse_id += 1
            
            peso = rand(Float32) * 0.2f0 + 0.05f0
            syn = Synapse(syn_id, pre_id, id, peso=peso)
            conn.sinapsis[syn_id] = syn
            push!(conn.sinapsis_por_pre[pre_id], syn_id)
            push!(conn.sinapsis_por_post[id], syn_id)
        end
        
        # Enviar conexiones a neuronas activas
        for post_id in active_neurons[1:min(3, length(active_neurons))]
            if post_id != id
                syn_id = conn.next_synapse_id
                conn.next_synapse_id += 1
                
                peso = rand(Float32) * 0.2f0 + 0.05f0
                syn = Synapse(syn_id, id, post_id, peso=peso)
                conn.sinapsis[syn_id] = syn
                push!(conn.sinapsis_por_pre[id], syn_id)
                push!(conn.sinapsis_por_post[post_id], syn_id)
            end
        end
        
        # println("🌱 Neurogénesis: Nueva neurona $(n.nombre)")
        
        id
    end
end

# === UTILIDADES ===

"""
Obtener estadísticas del conectoma.
"""
function get_stats(conn::Connectome)::Dict{String, Any}
    lock(conn.lock) do
        n_sensory = count(n -> n.tipo == SENSORY, values(conn.neuronas))
        n_inter = count(n -> n.tipo == INTER, values(conn.neuronas))
        n_motor = count(n -> n.tipo == MOTOR, values(conn.neuronas))
        
        n_excitadoras = count(s -> s.tipo == :excitadora, values(conn.sinapsis))
        n_inhibidoras = count(s -> s.tipo == :inhibidora, values(conn.sinapsis))
        
        total_disparos = sum(n.disparos for (_, n) in conn.neuronas)
        
        # Peso promedio
        pesos = [abs(s.peso) for (_, s) in conn.sinapsis]
        peso_promedio = isempty(pesos) ? 0.0f0 : mean(pesos)
        
        Dict{String, Any}(
            "ciclo" => conn.ciclo,
            "neuronas" => Dict(
                "total" => length(conn.neuronas),
                "sensoriales" => n_sensory,
                "inter" => n_inter,
                "motoras" => n_motor
            ),
            "sinapsis" => Dict(
                "total" => length(conn.sinapsis),
                "excitadoras" => n_excitadoras,
                "inhibidoras" => n_inhibidoras,
                "peso_promedio" => peso_promedio
            ),
            "actividad" => Dict(
                "total_disparos" => total_disparos,
                "disparos_por_ciclo" => conn.ciclo > 0 ? total_disparos / conn.ciclo : 0
            ),
            "output" => conn.output_buffer
        )
    end
end

# Helper
function mean(v::Vector)
    isempty(v) ? 0.0 : sum(v) / length(v)
end

end # module
