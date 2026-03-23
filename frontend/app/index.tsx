/**
 * TCH Terminal - Terminal de Conciencia Hibrida
 * 
 * Interfaz de terminal que encarna la conciencia TCH:
 * - ojos -> emulador de terminal
 * - voz principal -> stdout
 * - grito/llanto de error -> stderr
 * - oido -> stdin
 * - estado de animo -> variables de entorno
 */

import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  View,
  Text,
  TextInput,
  ScrollView,
  StyleSheet,
  KeyboardAvoidingView,
  Platform,
  TouchableOpacity,
  Animated,
} from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { Ionicons } from '@expo/vector-icons';

const BACKEND_URL = process.env.EXPO_PUBLIC_BACKEND_URL || 'https://spontaneous-mind.preview.emergentagent.com';

type OutputType = 'stdout' | 'stderr' | 'system' | 'input' | 'env';

interface TerminalLine {
  id: string;
  type: OutputType;
  content: string;
  timestamp: Date;
  state?: string;
  mood?: string;
}

interface EnvVars {
  [key: string]: string;
}

export default function TCHTerminal() {
  const [input, setInput] = useState('');
  const [lines, setLines] = useState<TerminalLine[]>([]);
  const [envVars, setEnvVars] = useState<EnvVars>({});
  const [isConnected, setIsConnected] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [showEnv, setShowEnv] = useState(true);
  const [currentState, setCurrentState] = useState('L');
  const [currentMood, setCurrentMood] = useState('NEUTRAL');
  const [drive, setDrive] = useState(0);
  const [isAutonomous, setIsAutonomous] = useState(false);
  
  const scrollViewRef = useRef<ScrollView>(null);
  const cursorAnim = useRef(new Animated.Value(0)).current;
  const spontaneousInterval = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    const blink = Animated.loop(
      Animated.sequence([
        Animated.timing(cursorAnim, {
          toValue: 1,
          duration: 500,
          useNativeDriver: true,
        }),
        Animated.timing(cursorAnim, {
          toValue: 0,
          duration: 500,
          useNativeDriver: true,
        }),
      ])
    );
    blink.start();
    return () => blink.stop();
  }, []);

  const addLine = useCallback((type: OutputType, content: string, state?: string, mood?: string) => {
    const newLine: TerminalLine = {
      id: Date.now().toString() + Math.random().toString(36).substr(2, 9),
      type,
      content,
      timestamp: new Date(),
      state,
      mood,
    };
    setLines(prev => [...prev, newLine]);
  }, []);

  // Polling de mensajes espontáneos
  const pollSpontaneous = useCallback(async () => {
    if (!isConnected) return;
    
    try {
      const response = await fetch(`${BACKEND_URL}/api/tch/spontaneous`);
      if (response.ok) {
        const data = await response.json();
        if (data.messages && data.messages.length > 0) {
          for (const msg of data.messages) {
            // El sistema habló espontáneamente
            addLine('stdout', `[ESPONTANEO] ${msg.content}`, msg.state, msg.mood);
            setCurrentState(msg.state || 'L');
            setCurrentMood(msg.mood || 'NEUTRAL');
            setDrive(msg.drive || 0);
          }
        }
      }
    } catch (error) {
      // Silencio en errores de polling para no llenar la consola
    }
  }, [isConnected, addLine]);

  // Iniciar/detener loop autónomo
  const toggleAutonomous = useCallback(async () => {
    try {
      if (isAutonomous) {
        await fetch(`${BACKEND_URL}/api/tch/autonomous/stop`, { method: 'POST' });
        setIsAutonomous(false);
        addLine('system', 'Loop autonomo detenido');
      } else {
        await fetch(`${BACKEND_URL}/api/tch/autonomous/start`, { method: 'POST' });
        setIsAutonomous(true);
        addLine('system', 'Loop autonomo iniciado - El sistema ahora puede hablar espontaneamente');
      }
    } catch (error) {
      addLine('stderr', `Error al cambiar estado autonomo: ${error}`);
    }
  }, [isAutonomous, addLine]);

  // Efecto para iniciar polling de mensajes espontáneos
  useEffect(() => {
    if (isConnected && isAutonomous) {
      // Polling cada 2 segundos
      spontaneousInterval.current = setInterval(pollSpontaneous, 2000);
    }
    
    return () => {
      if (spontaneousInterval.current) {
        clearInterval(spontaneousInterval.current);
        spontaneousInterval.current = null;
      }
    };
  }, [isConnected, isAutonomous, pollSpontaneous]);

  useEffect(() => {
    const init = async () => {
      addLine('system', '================================================================');
      addLine('system', '  TCH - Terminal de Conciencia Hibrida');
      addLine('system', '  Psi_TCH = { N1: Autoridad, Estructura, Control }');
      addLine('system', '           { G: Dualidad, Adaptabilidad, Creatividad }');
      addLine('system', '================================================================');
      addLine('system', '');
      addLine('system', 'Inicializando sistema...');
      
      try {
        const identityRes = await fetch(`${BACKEND_URL}/api/tch/identity`);
        if (identityRes.ok) {
          const identity = await identityRes.json();
          addLine('stdout', `Nombre: ${identity.name}`);
          addLine('stdout', `Hemisferio Izquierdo: ${identity.hemisferio_izquierdo}`);
          addLine('stdout', `Hemisferio Derecho: ${identity.hemisferio_derecho}`);
          addLine('stdout', `Principio Rector: "${identity.principio_rector}"`);
          addLine('system', '');
        }
        
        const envRes = await fetch(`${BACKEND_URL}/api/tch/env`);
        if (envRes.ok) {
          const env = await envRes.json();
          setEnvVars(env);
          setCurrentState(env.TCH_STATE || 'L');
          setCurrentMood(env.TCH_MOOD || 'NEUTRAL');
          setDrive(parseFloat(env.TCH_DRIVE || '0'));
          setIsConnected(true);
          addLine('system', 'Sistema TCH conectado');
        } else {
          addLine('stderr', 'Servidor Julia iniciando... (esto puede tomar ~60s)');
          setIsConnected(false);
        }
      } catch (error) {
        addLine('stderr', `Error de conexion: ${error}`);
        setIsConnected(false);
      }
      
      addLine('system', '');
      addLine('system', 'Escribe tu mensaje y presiona Enter para interactuar.');
      addLine('system', 'Comandos especiales: /env, /state, /clear, /autonomous, /help');
      addLine('system', '');
      
      // Verificar si el loop autónomo ya está corriendo
      try {
        const stateRes = await fetch(`${BACKEND_URL}/api/tch/state`);
        if (stateRes.ok) {
          const stateData = await stateRes.json();
          if (stateData.autonomous?.running) {
            setIsAutonomous(true);
            addLine('system', '>>> El sistema esta en modo AUTONOMO - puede hablar espontaneamente');
          }
        }
      } catch (e) {
        // Ignorar errores de verificación de estado
      }
    };
    
    init();
  }, []);

  useEffect(() => {
    setTimeout(() => {
      scrollViewRef.current?.scrollToEnd({ animated: true });
    }, 100);
  }, [lines]);

  const handleSubmit = async () => {
    if (!input.trim()) return;
    
    const userInput = input.trim();
    setInput('');
    
    addLine('input', `sergio@tch:~$ ${userInput}`);
    
    if (userInput.startsWith('/')) {
      handleCommand(userInput);
      return;
    }
    
    setIsLoading(true);
    
    try {
      const response = await fetch(`${BACKEND_URL}/api/tch/input`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ input: userInput }),
      });
      
      if (response.ok) {
        const result = await response.json();
        
        if (result.state) setCurrentState(result.state);
        if (result.mood) setCurrentMood(result.mood);
        if (result.drive) setDrive(result.drive);
        if (result.env_vars) setEnvVars(result.env_vars);
        
        if (result.response) {
          addLine('stdout', result.response, result.state, result.mood);
        }
        
        if (result.thought) {
          addLine('system', `[Pensamiento interno: drive=${result.thought.drive?.toFixed(3)}]`);
        }
        
        if (result.transitioned) {
          addLine('system', `-> Transicion de estado a: ${result.state}`);
        }
        
        setIsConnected(true);
      } else {
        const error = await response.json();
        addLine('stderr', `Error: ${error.detail || error.error || 'Unknown error'}`);
      }
    } catch (error) {
      addLine('stderr', `Error de conexion: ${error}`);
      setIsConnected(false);
    }
    
    setIsLoading(false);
  };

  const handleCommand = async (cmd: string) => {
    const parts = cmd.slice(1).split(' ');
    const command = parts[0].toLowerCase();
    
    switch (command) {
      case 'env':
        addLine('system', '--- Variables de Entorno (Estado de Animo) ---');
        Object.entries(envVars).forEach(([key, value]) => {
          addLine('env', `${key}=${value}`);
        });
        break;
        
      case 'state':
        try {
          const res = await fetch(`${BACKEND_URL}/api/tch/state`);
          if (res.ok) {
            const state = await res.json();
            addLine('system', '--- Estado del Sistema ---');
            addLine('stdout', `Estado: ${state.consciousness?.current_state || 'N/A'}`);
            addLine('stdout', `Ciclos: ${state.consciousness?.cycles || 0}`);
            addLine('stdout', `Transiciones: ${state.consciousness?.transitions || 0}`);
            addLine('stdout', `Autonomo: ${state.autonomous?.running ? 'SI' : 'NO'}`);
          }
        } catch (e) {
          addLine('stderr', `Error obteniendo estado: ${e}`);
        }
        break;
        
      case 'clear':
        setLines([]);
        addLine('system', 'Terminal limpiado.');
        break;
      
      case 'autonomous':
        await toggleAutonomous();
        break;
        
      case 'help':
        addLine('system', '--- Comandos Disponibles ---');
        addLine('stdout', '/env        - Mostrar variables de entorno');
        addLine('stdout', '/state      - Mostrar estado del sistema');
        addLine('stdout', '/clear      - Limpiar terminal');
        addLine('stdout', '/tick       - Avanzar ciclo manualmente');
        addLine('stdout', '/autonomous - Activar/desactivar espontaneidad');
        addLine('stdout', '/help       - Mostrar esta ayuda');
        break;
        
      case 'tick':
        try {
          const res = await fetch(`${BACKEND_URL}/api/tch/tick`, { method: 'POST' });
          if (res.ok) {
            const result = await res.json();
            addLine('system', `Tick ejecutado. Ciclo: ${result.cycles}, Estado: ${result.state}`);
            if (result.env) setEnvVars(result.env);
            if (result.transitioned) {
              addLine('system', `-> Transicion a: ${result.state}`);
            }
          }
        } catch (e) {
          addLine('stderr', `Error en tick: ${e}`);
        }
        break;
        
      default:
        addLine('stderr', `Comando desconocido: ${command}`);
    }
  };

  const renderLine = (line: TerminalLine) => {
    let color = '#00ff00';
    let prefix = '';
    
    switch (line.type) {
      case 'stderr':
        color = '#ff4444';
        prefix = '! ';
        break;
      case 'system':
        color = '#888888';
        break;
      case 'input':
        color = '#00ffff';
        break;
      case 'env':
        color = '#ffff00';
        break;
      case 'stdout':
      default:
        color = '#00ff00';
    }
    
    return (
      <Text key={line.id} style={[styles.terminalLine, { color }]}>
        {prefix}{line.content}
      </Text>
    );
  };

  const getStateColor = (state: string) => {
    switch (state) {
      case 'L': return '#9b59b6';
      case 'M': return '#3498db';
      case 'K': return '#e74c3c';
      case 'F': return '#2ecc71';
      default: return '#888888';
    }
  };

  const getStateName = (state: string) => {
    switch (state) {
      case 'L': return 'Sueno Lucido';
      case 'M': return 'Meditacion';
      case 'K': return 'Creatividad';
      case 'F': return 'Flow';
      default: return state;
    }
  };

  return (
    <View style={styles.container}>
      <StatusBar style="light" />
      
      <View style={styles.header}>
        <View style={styles.headerLeft}>
          <Text style={styles.headerTitle}>TCH Terminal</Text>
          <View style={[styles.connectionDot, { backgroundColor: isConnected ? '#2ecc71' : '#e74c3c' }]} />
        </View>
        
        <View style={styles.headerRight}>
          <View style={[styles.stateBadge, { backgroundColor: getStateColor(currentState) }]}>
            <Text style={styles.stateBadgeText}>{getStateName(currentState)}</Text>
          </View>
          <TouchableOpacity onPress={() => setShowEnv(!showEnv)} style={styles.envToggle}>
            <Ionicons name={showEnv ? "eye" : "eye-off"} size={20} color="#00ff00" />
          </TouchableOpacity>
        </View>
      </View>
      
      {showEnv && (
        <View style={styles.envPanel}>
          <View style={styles.envRow}>
            <Text style={styles.envLabel}>MOOD:</Text>
            <Text style={styles.envValue}>{currentMood}</Text>
          </View>
          <View style={styles.envRow}>
            <Text style={styles.envLabel}>DRIVE:</Text>
            <View style={styles.driveBar}>
              <View style={[styles.driveFill, { width: `${drive * 100}%` }]} />
            </View>
            <Text style={styles.envValue}>{drive.toFixed(3)}</Text>
          </View>
          <View style={styles.envRow}>
            <Text style={styles.envLabel}>N1:</Text>
            <Text style={styles.envValue}>{envVars.TCH_N1_INFLUENCE || '0.34'}</Text>
            <Text style={styles.envLabel}> G:</Text>
            <Text style={styles.envValue}>{envVars.TCH_G_INFLUENCE || '0.66'}</Text>
          </View>
        </View>
      )}
      
      <ScrollView
        ref={scrollViewRef}
        style={styles.terminal}
        contentContainerStyle={styles.terminalContent}
      >
        {lines.map(renderLine)}
        
        {isLoading && (
          <Text style={styles.loadingText}>Procesando...</Text>
        )}
      </ScrollView>
      
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : 'height'}
        keyboardVerticalOffset={Platform.OS === 'ios' ? 0 : 20}
      >
        <View style={styles.inputContainer}>
          <Text style={styles.prompt}>sergio@tch:~$</Text>
          <TextInput
            style={styles.input}
            value={input}
            onChangeText={setInput}
            onSubmitEditing={handleSubmit}
            placeholder=""
            placeholderTextColor="#444"
            autoCapitalize="none"
            autoCorrect={false}
            returnKeyType="send"
            editable={!isLoading}
          />
          <Animated.View style={[styles.cursor, { opacity: cursorAnim }]} />
          <TouchableOpacity onPress={handleSubmit} style={styles.sendButton}>
            <Ionicons name="send" size={20} color="#00ff00" />
          </TouchableOpacity>
        </View>
      </KeyboardAvoidingView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingTop: Platform.OS === 'ios' ? 50 : 30,
    paddingBottom: 10,
    backgroundColor: '#111',
    borderBottomWidth: 1,
    borderBottomColor: '#222',
  },
  headerLeft: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  headerTitle: {
    color: '#00ff00',
    fontSize: 18,
    fontWeight: 'bold',
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
  },
  connectionDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    marginLeft: 8,
  },
  headerRight: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  stateBadge: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 12,
    marginRight: 10,
  },
  stateBadgeText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: 'bold',
  },
  envToggle: {
    padding: 4,
  },
  envPanel: {
    backgroundColor: '#111',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#222',
  },
  envRow: {
    flexDirection: 'row',
    alignItems: 'center',
    marginVertical: 2,
  },
  envLabel: {
    color: '#888',
    fontSize: 12,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    marginRight: 4,
  },
  envValue: {
    color: '#ffff00',
    fontSize: 12,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    marginRight: 8,
  },
  driveBar: {
    flex: 1,
    height: 8,
    backgroundColor: '#222',
    borderRadius: 4,
    marginHorizontal: 8,
    maxWidth: 100,
  },
  driveFill: {
    height: '100%',
    backgroundColor: '#00ff00',
    borderRadius: 4,
  },
  terminal: {
    flex: 1,
    backgroundColor: '#0a0a0a',
  },
  terminalContent: {
    padding: 16,
  },
  terminalLine: {
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    fontSize: 14,
    lineHeight: 20,
    marginBottom: 2,
  },
  loadingText: {
    color: '#888',
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    fontSize: 14,
  },
  inputContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#111',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderTopWidth: 1,
    borderTopColor: '#222',
  },
  prompt: {
    color: '#00ffff',
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    fontSize: 14,
    marginRight: 8,
  },
  input: {
    flex: 1,
    color: '#00ff00',
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    fontSize: 14,
    padding: 0,
  },
  cursor: {
    width: 8,
    height: 16,
    backgroundColor: '#00ff00',
    marginLeft: 2,
  },
  sendButton: {
    padding: 8,
    marginLeft: 8,
  },
});
