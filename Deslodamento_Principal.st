(*============================================================================
  PROGRAMA PRINCIPAL - CICLO DE DESLODAMENTO
  
  Projeto: Centrífuga de Suco - Sistema de Deslodamento
  Linguagem: Structured Text (ST)
  Plataforma: CODESYS
  
  Requisitos:
  1. Inicialização: DI1 pressionado por mais de 2 segundos
  2. Parada: DI2 desativa o ciclo
  3. Saída: DO1 (válvula de deslodamento)
  4. Display: Contador de ciclos + Mensagem de status
  
  Presets Padrão:
  - Tempo entre pulsos: 5 segundos
  - Deslodamento parcial: 1 segundo
  - Deslodamento parcial longo: 6 segundos
  - Deslodamento total: 30 segundos
============================================================================*)

PROGRAM Desludging_Cycle
VAR
  (* ENTRADAS DIGITAIS *)
  DI1_Start : BOOL;              (* Botão iniciar - hold 2 segundos *)
  DI2_Stop : BOOL;               (* Botão parar ciclo *)
  
  (* SAÍDAS DIGITAIS *)
  DO1_Valve : BOOL;              (* Válvula de deslodamento *)
  
  (* TIMERS *)
  Start_Hold_Timer : TON;         (* Timer para hold 2 segundos *)
  Pulse_Timer : TON;              (* Timer entre pulsos *)
  Desludge_Timer : TON;           (* Timer de deslodamento *)
  
  (* PRESETS (CONFIGURÁVEIS VIA WEBVISU) *)
  Time_Between_Pulses : DINT := 5000;      (* 5 segundos em ms *)
  Time_Partial_Desludge : DINT := 1000;    (* 1 segundo em ms *)
  Time_Long_Partial : DINT := 6000;        (* 6 segundos em ms *)
  Time_Total_Desludge : DINT := 30000;     (* 30 segundos em ms *)
  
  (* MÁQUINA DE ESTADOS *)
  State : INT := 0;                        (* 0=Idle, 1=Partial, 2=Long, 3=Total, 4=Waiting *)
  Cycle_Count : DINT := 0;                 (* Contador de ciclos completos *)
  Pulse_Count : INT := 0;                  (* Contador de pulsos dentro de um ciclo *)
  
  (* STATUS E MENSAGENS *)
  System_Status : STRING := 'PARADO';
  Current_Desludge_Type : STRING := '';
  Is_Running : BOOL := FALSE;
  
  (* TRAÇO PARA GRÁFICO *)
  DO1_Trace : REAL := 0.0;                 (* Valor analógico para gráfico *)
  
END_VAR

(*============================================================================
  LÓGICA PRINCIPAL
============================================================================*)

(* Detecção de pressão no botão START (> 2 segundos) *)
Start_Hold_Timer(IN := DI1_Start, PT := T#2s);

IF Start_Hold_Timer.Q AND NOT Is_Running THEN
  Is_Running := TRUE;
  State := 1;  (* Inicia com deslodamento parcial *)
  Pulse_Count := 0;
  System_Status := 'INICIADO';
END_IF;

(* Parada pelo botão STOP *)
IF DI2_Stop THEN
  Is_Running := FALSE;
  DO1_Valve := FALSE;
  State := 0;
  System_Status := 'PARADO';
  Current_Desludge_Type := '';
  Pulse_Count := 0;
END_IF;

(*============================================================================
  MÁQUINA DE ESTADOS - CICLO DE DESLODAMENTO
============================================================================*)

IF Is_Running THEN
  
  CASE State OF
  
    (* Estado 1: DESLODAMENTO PARCIAL *)
    1:
      Current_Desludge_Type := 'Ciclo de deslodamento parcial';
      System_Status := 'DESLODAMENTO PARCIAL';
      
      Desludge_Timer(IN := TRUE, PT := INT_TO_TIME(Time_Partial_Desludge));
      DO1_Valve := TRUE;
      DO1_Trace := 1.0;
      
      IF Desludge_Timer.Q THEN
        DO1_Valve := FALSE;
        DO1_Trace := 0.0;
        Desludge_Timer(IN := FALSE);
        INC(Pulse_Count);
        State := 4;  (* Vai para espera *)
      END_IF;
    
    (* Estado 2: DESLODAMENTO PARCIAL LONGO *)
    2:
      Current_Desludge_Type := 'Ciclo de deslodamento parcial longo';
      System_Status := 'DESLODAMENTO PARCIAL LONGO';
      
      Desludge_Timer(IN := TRUE, PT := INT_TO_TIME(Time_Long_Partial));
      DO1_Valve := TRUE;
      DO1_Trace := 1.0;
      
      IF Desludge_Timer.Q THEN
        DO1_Valve := FALSE;
        DO1_Trace := 0.0;
        Desludge_Timer(IN := FALSE);
        INC(Pulse_Count);
        State := 4;
      END_IF;
    
    (* Estado 3: DESLODAMENTO TOTAL *)
    3:
      Current_Desludge_Type := 'Ciclo de deslodamento total';
      System_Status := 'DESLODAMENTO TOTAL';
      
      Desludge_Timer(IN := TRUE, PT := INT_TO_TIME(Time_Total_Desludge));
      DO1_Valve := TRUE;
      DO1_Trace := 1.0;
      
      IF Desludge_Timer.Q THEN
        DO1_Valve := FALSE;
        DO1_Trace := 0.0;
        Desludge_Timer(IN := FALSE);
        
        (* Ciclo completo finalizado *)
        INC(Cycle_Count);
        Pulse_Count := 0;
        Is_Running := FALSE;
        System_Status := 'CICLO COMPLETO';
        Current_Desludge_Type := 'Ciclo completo finalizado';
      END_IF;
    
    (* Estado 4: ESPERA ENTRE PULSOS *)
    4:
      Current_Desludge_Type := 'Aguardando próximo pulso';
      System_Status := 'AGUARDANDO';
      DO1_Valve := FALSE;
      DO1_Trace := 0.0;
      
      Pulse_Timer(IN := TRUE, PT := INT_TO_TIME(Time_Between_Pulses));
      
      IF Pulse_Timer.Q THEN
        Pulse_Timer(IN := FALSE);
        
        (* Sequência: 3 pulsos parciais, 1 longo, 1 total *)
        IF Pulse_Count = 3 THEN
          State := 2;  (* Deslodamento longo *)
        ELSIF Pulse_Count = 4 THEN
          State := 3;  (* Deslodamento total *)
        ELSE
          State := 1;  (* Volta para deslodamento parcial *)
        END_IF;
      END_IF;
  
  END_CASE;

ELSE
  (* Sistema não está rodando *)
  DO1_Valve := FALSE;
  DO1_Trace := 0.0;
  Desludge_Timer(IN := FALSE);
  Start_Hold_Timer(IN := FALSE);
  Pulse_Timer(IN := FALSE);
END_IF;

(*============================================================================
  SAÍDAS
============================================================================*)

(* A saída digital DO1 já é controlada pelos estados acima *)

END_PROGRAM
