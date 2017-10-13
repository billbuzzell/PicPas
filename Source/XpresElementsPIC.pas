{
XpresElementsPIC
================
Definiciones para el manejo de los elementos del compilador: procedimientos, constantes,
variables, tipos, ....
Todos estos elementos se deberían almacenar en una estrucutura de arbol.
Esta unidad esta basada en la unidad XpresElements de Xpres, pero adaptada a la
arquitectura de los PIC y al lenguaje de PicPas.
Por Tito Hinostroza.
}
unit XpresElementsPIC;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, fgl, XpresTypesPIC, XpresBas, LCLProc;
const
  ADRR_ERROR = $FFFF;
type
  {Estos tipos están relacionados con el hardware, y tal vez deberían estar declarados
  en otra unidad. Pero se ponen aquí porque son pocos.
  La idea es que sean simples contenedores de direcciones físicas. En un inicio se pensó
  declararlos como RECORD por velocidad (para no usar memoria dinámica), pero dado que no
  se tienen requerimientos altos de velocidad en PicPas, se declaran como clases. }
  //Tipo de registro
  TPicRegType = (prtWorkReg,   //de trabajo
                 prtAuxReg,    //auxiliar
                 prtStkReg     //registro de pila
  );
  { TPicRegister }
  {Objeto que sirve para modelar a un registro del PIC (una dirección de memoria, usada
   para un fin particular)}
  TPicRegister = class
  public
    offs   : byte;      //Desplazamiento en memoria
    bank   : byte;      //Banco del registro
    assigned: boolean;  //indica si tiene una dirección física asignada
    used   : boolean;   //Indica si está usado.
    typ    : TPicRegType; //Tipo de registro
    function AbsAdrr: word;  //Diección absoluta
    procedure Assign(srcReg: TPicRegister);
  end;
  TPicRegister_list = specialize TFPGObjectList<TPicRegister>; //lista de registros

  { TPicRegisterBit }
  {Objeto que sirve para modelar a un bit del PIC (una dirección de memoria, usada
   para un fin particular)}
  TPicRegisterBit = class
  public
    offs   : byte;      //Desplazamiento en memoria
    bank   : byte;      //Banco del registro
    bit    : byte;      //bit del registro
    assigned: boolean;  //indica si tiene una dirección física asignada
    used   : boolean;   //Indica si está usado.
    typ    : TPicRegType; //Tipo de registro
    function AbsAdrr: word;  //Diección absoluta
    procedure Assign(srcReg: TPicRegisterBit);
  end;
  TPicRegisterBit_list = specialize TFPGObjectList<TPicRegisterBit>; //lista de registros

type
  //Tipos de elementos del lenguaje
  TxpIDClass = (eltNone,  //sin tipo
                 eltMain,  //programa principal
                 eltVar,   //variable
                 eltFunc,  //función
                 eltCons,  //constante
                 eltType,  //tipo
                 eltUnit,  //unidad
                 eltBody    //cuerpo del programa
                );

  TxpElement = class;
  TxpElements = specialize TFPGObjectList<TxpElement>;

  TxpEleBody = class;

  //Datos sobre la llamada a un elemento desde otro elemento
  TxpEleCaller = class
    curPos: TSrcPos;    //Posición desde donde es llamado
    curBnk: byte;       //banco RAM, desde donde se llama
    caller: TxpElement; //función que llama a esta función
  end;
  TxpListCallers = specialize TFPGObjectList<TxpEleCaller>;

  { TxpElement }
  //Clase base para todos los elementos
  TxpElement = class
  private
    function AddElement(elem: TxpElement): TxpElement;
  public  //Gestion de llamadas al elemento
    lstCallers: TxpListCallers;  //Lista de funciones que llaman a esta función.
    OnAddCaller: function(elem: TxpElement): TxpEleCaller of object;
    function AddCaller: TxpEleCaller;
    function nCalled: integer;  //número de llamadas
    function IsCalledBy(callElem: TxpElement): boolean; //Identifica a un llamador
    function IsCAlledAt(callPos: TSrcPos): boolean;
    function IsDeclaredAt(decPos: TSrcPos): boolean;
    function FindCalling(callElem: TxpElement): TxpEleCaller; //Identifica a un llamada
    function RemoveCallsFrom(callElem: TxpElement): integer; //Elimina llamadas
    procedure ClearCallers;  //limpia lista de llamantes
    function DuplicateIn(list: TxpElements): boolean; virtual;
  public
    name : string;        //Nombre de la variable, constante, unidad, tipo, ...
    Parent: TxpElement;   //Referencia al padre
    idClass: TxpIDClass; //No debería ser necesario
    elements: TxpElements; //Referencia a nombres anidados, cuando sea función
    function Path: string;
    function FindIdxElemName(const eName: string; var idx0: integer): boolean;
    function LastNode: TxpElement;
    function BodyNode: TxpEleBody;
    function Index: integer;
    constructor Create; virtual;
    destructor Destroy; override;
  public  //Ubicación física de la declaración del elmento
    posCtx: TPosCont;  //Ubicación en el código fuente
    {Datos de la ubicación en el código fuente, donde el elemento es declarado. Guardan
    parte de la información de posCtx, pero se mantiene, aún después de cerrar los
    contextos de entrada.}
    srcDec: TSrcPos;
    {Posición final de la declaración. Esto es útil en los elementos que TxpEleBody,
    para delimitar el bloque de código.}
    srcEnd: TSrcPos;
    function posXYin(const posXY: TPoint): boolean;
  end;

  TVarOffs = word;
  TVarBank = byte;

  //Clase para modelar al bloque principal
  { TxpEleMain }
  TxpEleMain = class(TxpElement)
    //Como este nodo representa al programa principal, se incluye información física
    srcSize: integer;  {Tamaño del código compilado. En la primera pasada, es referencial,
                        porque el tamaño puede variar al reubicarse.}
    constructor Create; override;
  end;

  //Categorías de tipos
  TxpCatType = (
    tctAtomic,  //tipo básico
    tctArray,   //arreglo de otro tipo
    tctRecord   //registro de varios campos
  );

  TxpEleType= class;

  //Tipo operación
  TxpOperation = class
    OperatType : TxpEleType;   //tipo de Operando sobre el cual se aplica la operación.
    proc       : TProcExecOperat;  //Procesamiento de la operación
  end;

  TxpOperations = specialize TFPGObjectList<TxpOperation>; //lista de operaciones

  { TxpOperator }
  //Operador
  TxpOperator = class
  private
    Operations: TxpOperations;  //operaciones soportadas. Debería haber tantos como
                                //Num. Operadores * Num.Tipos compatibles.
  public
    txt  : string;    //cadena del operador '+', '-', '++', ...
    prec : byte;      //precedencia
    name : string;    //nombre de la operación (suma, resta)
    kind : TxpOperatorKind;   //Tipo de operador
    OperationPre: TProcExecOperat;  {Operación asociada al Operador. Usado cuando es un
                                    operador unario PRE. }
    OperationPost: TProcExecOperat; {Operación asociada al Operador. Usado cuando es un
                                    operador unario POST }
    function CreateOperation(OperandType: TxpEleType; proc: TProcExecOperat
      ): TxpOperation;  //Crea operación
    function FindOperation(typ0: TxpEleType): TxpOperation;  //Busca una operación para este operador
    constructor Create;
    destructor Destroy; override;
  end;
  TxpOperators = specialize TFPGObjectList<TxpOperator>; //lista de operadores

  { TxpEleType }
  {Clase para modelar a los tipos definidos por el usuario y a los tipos del sistema.
  Es una clase relativamente extensa, debido a la flxibilidad que ofrecen lso tipos en
  Pascal.}
  TxpEleType= class(TxpElement)
  public   //Eventos
    {Estos eventos son llamados automáticamente por el Analizador de expresiones.
    Por seguridad, debe implementarse siempre para cada tipo creado. La implementación
    más simple sería devolver en "res", el operando "p1^".}
    OperationLoad: TProcExecOperat; {Evento. Es llamado cuando se pide evaluar una
                                 expresión de un solo operando de este tipo. Es un caso
                                 especial que debe ser tratado por la implementación}
    OnGetItem    : TTypFieldProc;  {Es llamado cuando se pide leer un ítem de un
                                   arreglo. Debe devolver una expresión con el resultado
                                   dal ítem leído.}
    OnSetItem    : TTypFieldProc;  {Es llamado cuando se pide escribir un ítem a un
                                   arreglo.}
    OnClearItems : TTypFieldProc;  {Usado para la rutina que limpia los ítems de
                                   un arreglo.}
    {Estos eventos NO se generan automáticamente en TCompilerBase, sino que es la
    implementación del tipo, la que deberá llamarlos. Son como una ayuda para facilitar
    la implementación. OnPush y OnPop, son útiles para cuando la implementación va a
    manejar pila.}
    OnSaveToStk: procedure of object;  //Salva datos en reg. de Pila
    OnLoadToReg: TProcLoadOperand; {Se usa cuando se solicita cargar un operando
                                 (de este tipo) en la pila. }
    OnDefineRegister : procedure of object; {Se usa cuando se solicita descargar un operando
                                 (de este tipo) de la pila. }
    OnGlobalDef: TProcDefineVar; {Es llamado cada vez que se encuentra la
                                  declaración de una variable (de este tipo) en el ámbito global.}
  public
    copyOf  : TxpEleType;  //Indica que es una copia de otro tipo
    grp     : TTypeGroup;  //Grupo del tipo (numérico, cadena, etc)
    size    : smallint;    //Tamaño en bytes del tipo
    catType : TxpCatType;
    arrSize : integer;     //Tamaño, cuando es tctArray
    refType : TxpEleType;  //Referencia a otro tipo. Valido cuando es puntero o arreglo.
    {Bandera para indicar si la variable, ha sido declarada en la sección INTERFACE. Este
    campo es úitl para cuando se procesan unidades.}
    InInterface: boolean;
  public  //Campos de operadores
    Operators: TxpOperators;      //Operadores soportados
    operAsign: TxpOperator;       //Se guarda una referencia al operador de aignación
    function CreateBinaryOperator(txt: string; prec: byte; OpName: string
      ): TxpOperator;
    function CreateUnaryPreOperator(txt: string; prec: byte; OpName: string;
      proc: TProcExecOperat): TxpOperator;
    function CreateUnaryPostOperator(txt: string; prec: byte; OpName: string;
      proc: TProcExecOperat): TxpOperator;
    //Funciones de búsqueda
    function FindBinaryOperator(const OprTxt: string): TxpOperator;
    function FindUnaryPreOperator(const OprTxt: string): TxpOperator;
    function FindUnaryPostOperator(const OprTxt: string): TxpOperator;
    procedure SaveToStk;
  public  //Manejo de campos
    fields: TTypFields;
    procedure CreateField(metName: string; proc: TTypFieldProc);
  public  //Identificación
    function IsBitSize: boolean;
    function IsByteSize: boolean;
    function IsWordSize: boolean;
    function IsDWordSize: boolean;
    procedure DefineRegister;
  public
    constructor Create; override;
    destructor Destroy; override;
  end;
  TxpEleTypes= specialize TFPGObjectList<TxpEleType>; //lista de variables

  { TxpEleCon }
  //Clase para modelar a las constantes
  TxpEleCon = class(TxpElement)
    typ: TxpEleType;     //Tipo del elemento, si aplica
    //valores de la constante
    val : TConsValue;
    constructor Create; override;
  end;
  TxpEleCons = specialize TFPGObjectList<TxpEleCon>; //lista de constantes

  {Descripción de la parte adicional en la declaración de una variable (como si
  es ABSOLUTE)}
  TAdicVarDec = record
    //Por el momento, el único parámetro adicional es ABSOLUTE
    isAbsol   : boolean;   //Indica si es ABSOLUTE
    absAddr   : integer;   //dirección ABSOLUTE
    absBit    : byte;      //bit ABSOLUTE
    //Posición donde empieza la declaración de parámetros adicionales de la variable
    srcDec    : TPosCont;
  end;

  { TxpEleVar }
  //Clase para modelar a las variables
  TxpEleVar = class(TxpElement)
  private
    ftyp: TxpEleType;
    function GetHavAdicPar: boolean;
    procedure SetHavAdicPar(AValue: boolean);
    function Gettyp: TxpEleType;
    procedure Settyp(AValue: TxpEleType);
  public   //Manejo de parámetros adicionales
    adicPar: TAdicVarDec;  //Parámetros adicionales en la declaración de la variable.
    //Referencia al elemento de tipo
    property typ: TxpEleType read Gettyp write Settyp;
    //Indica si la variable tiene parámetros adicionales en la declaración
    property havAdicPar: boolean read GetHavAdicPar write SetHavAdicPar;
  public
    {Bandera para indicar si la variable, ha sido declarada en la sección INTERFACE. Este
    campo es úitl para cuando se procesan unidades.}
    InInterface: boolean;
    //Bandera para indicar si la variable, se está usando como parámetro
    IsParameter: boolean;
    {Bandera para indicar que el valor de la variable se alamcena en lso registros de
    trabajo, es decir que se manejan, más como expresión que como variables. Se diseñó,
    como una forma rápida para pasar parámetros a funciones.}
    IsRegister : boolean;
    {Indica si la variables es temporal, es decir que se ha creado solo para acceder a
    una parte de otra variable, que si tiene almacenamiento físico.}
    IsTmp      : boolean;
    //Campos para guardar las direcciones físicas asignadas en RAM.
    adrBit : TPicRegisterBit;  //Dirección física, cuando es de tipo Bit/Boolean
    adrByte0: TPicRegister;   //Dirección física, cuando es de tipo Byte/Char/Word/DWord
    adrByte1: TPicRegister;   //Dirección física, cuando es de tipo Word/DWord
    adrByte2: TPicRegister;   //Dirección física, cuando es de tipo DWord
    adrByte3: TPicRegister;   //Dirección física, cuando es de tipo DWord
    function AbsAddr : word;   //Devuelve la dirección absoluta de la variable
    function AbsAddrL: word;   //Devuelve la dirección absoluta de la variable (LOW)
    function AbsAddrH: word;   //Devuelve la dirección absoluta de la variable (HIGH)
    function AbsAddrE: word;   //Devuelve la dirección absoluta de la variable (HIGH)
    function AbsAddrU: word;   //Devuelve la dirección absoluta de la variable (HIGH)
    function AddrString: string;  //Devuelve la dirección física como cadena
    function BitMask: byte;  //Máscara de bit, de acuerdo al valor del campo "bit".
    procedure ResetAddress;  //Limpia las direcciones físicas
    constructor Create; override;
    destructor Destroy; override;
  end;
  TxpEleVars = specialize TFPGObjectList<TxpEleVar>; //lista de variables

  //Parámetro de una función
  TxpParFunc = record
    name: string;    //nombre de parámetro
    typ : TxpEleType;  //Referencia al tipo
    pvar: TxpEleVar; //referencia a la variable que se usa para el parámetro
  end;

  TxpEleFun = class;
  { TxpEleFun }
  //Clase para almacenar información de las funciones
  TProcExecFunction = procedure(fun: TxpEleFun) of object;  //con índice de función
  TxpEleFun = class(TxpElement)
  public
    typ: TxpEleType;  //Referencia al tipo
    pars: array of TxpParFunc;  //parámetros de entrada
    adrr: integer;     //Dirección física, en donde se compila
    adrReturn: integer;  //Dirección física del RETURN final de la función.
    srcSize: integer;  {Tamaño del código compilado. En la primera pasada, es referencial,
                        porque el tamaño puede variar al reubicarse.}
    //Banco de RAM, al iniciar la eejcución de la subrutina.
    iniBnk: byte;
    {Bsndera que indica si se produce cambio de banco desde dentro del código de la
    función.}
    BankChanged: boolean;
    {Referencia a la función que implemanta, la rutina de porcesamiento que se debe
    hacer, antes de empezar a leer los parámetros de la función.}
    procParam: TProcExecFunction;
    {Referencia a la función que implementa, la llamada a la función en ensamblador.
    En funciones del sistema, puede que se implemente INLINE, sin llamada a subrutinas,
    pero en las funciones comunes, siempre usa CALL ... }
    procCall: TProcExecFunction;
    {Método que llama a una rutina que codificará la rutina ASM que implementa la función.
     La idea es que este campo solo se use para algunas funciones del sistema.}
    compile: TProcExecFunction;
    {Bandera para indicar si la función, ha sido implementada. Este campo es util, para
     cuando se usa FORWARD o cuando se compilan unidades.}
    Implemented: boolean;
    {Bandera para indicar si la función, ha sido declarada en la sección INTERFACE. Este
    campo es úitl para cuando se procesan unidades.}
    InInterface: boolean;
    {Indica si la función es una ISR. Se espera que solo exista una.}
    IsInterrupt : boolean;
    ///////////////
    procedure ClearParams;
    procedure CreateParam(parName: string; typ0: TxpEleType; pvar: TxpEleVar);
    function SameParams(Fun2: TxpEleFun): boolean;
    function ParamTypesList: string;
    function DuplicateIn(list: TxpElements): boolean; override;
    procedure SetElementsUnused;
    constructor Create; override;
  end;
  TxpEleFuns = specialize TFPGObjectList<TxpEleFun>;

  { TxpEleUnit }
  //Clase para modelar a las constantes
  TxpEleUnit = class(TxpElement)
  public
    srcFile: string;   //El archivo en donde está físicamente la unidad.
    constructor Create; override;
  end;
  TxpEleUnits = specialize TFPGObjectList<TxpEleUnit>; //lista de constantes

  //Clase para modelar al cuerpo principal del programa

  { TxpEleBody }
  TxpEleBody = class(TxpElement)
    adrr   : integer;  //dirección física
    constructor Create; override;
  end;

  { TxpEleDIREC }
  //Representa a una directiva. Diseñado para representar a los nodos {$IFDEF}
  TxpEleDIREC = class(TxpElement)
    ifDefResult  : boolean;   //valor booleano, de la expresión $IFDEF
    constructor Create; override;
  end;

  { TXpTreeElements }
  {Árbol de elementos. Se usa para el árbol de sinatxis y de directivas. Aquí es
  donde se guardará la referencia a todas los elementos (variables, constantes, ..)
  creados.
  Este árbol se usa también como un equivalente al NameSpace, porque se usa para
  buscar los nombres de los elementos, en una estructura en arbol.}
  TXpTreeElements = class
  private
    //Variables de estado para la búsqueda con FindFirst() - FindNext()
    curFindName: string;
    curFindNode: TxpElement;
    curFindIdx : integer;
    inUnit     : boolean;
  public
    main    : TxpEleMain;  //nodo raiz
    curNode : TxpElement;  //referencia al nodo actual
    AllVars    : TxpEleVars;
    AllFuncs   : TxpEleFuns;
    OnAddElement: procedure(xpElem: TxpElement) of object;  //Evento
    procedure Clear;
    procedure RefreshAllVars;
    procedure RefreshAllFuncs;
    function CurNodeName: string;
    function LastNode: TxpElement;
    function BodyNode: TxpEleBody;
    //funciones para llenado del arbol
    function AddElement(elem: TxpElement; verifDuplic: boolean=true): boolean;
    procedure AddElementAndOpen(elem: TxpElement);
    procedure OpenElement(elem: TxpElement);
    function ValidateCurElement: boolean;
    procedure CloseElement;
    //Métodos para identificación de nombres
    function FindNext: TxpElement;
    function FindFirst(const name: string): TxpElement;
    function FindNextFunc: TxpEleFun;
    function FindVar(varName: string): TxpEleVar;
    function GetElementBodyAt(posXY: TPoint): TxpEleBody;
    function GetElementCalledAt(const srcPos: TSrcPos): TxpElement;
    function GetELementDeclaredAt(const srcPos: TSrcPos): TxpElement;
  public  //constructor y destructror
    constructor Create; virtual;
    destructor Destroy; override;
  end;

var
  ///////////  Tipos del sistema ////////////////
  typNull : TxpEleType;
  typBit  : TxpEleType;
  typBool : TxpEleType;
  typByte : TxpEleType;
  typWord : TxpEleType;
  typDWord: TxpEleType;
  typChar : TxpEleType;
  //Operador nulo. Usado como valor cero.
  nullOper : TxpOperator;

implementation

{ TPicRegister }
function TPicRegister.AbsAdrr: word;
begin
  Result := bank * $80 + offs;
end;
procedure TPicRegister.Assign(srcReg: TPicRegister);
begin
  offs    := srcReg.offs;
  bank    := srcReg.bank;
  assigned:= srcReg.assigned;
  used    := srcReg.used;
  typ     := srcReg.typ;
end;
{ TPicRegisterBit }
function TPicRegisterBit.AbsAdrr: word;
begin
  Result := bank * $80 + offs;
end;
procedure TPicRegisterBit.Assign(srcReg: TPicRegisterBit);
begin
  offs    := srcReg.offs;
  bank    := srcReg.bank;
  bit     := srcReg.bit;
  assigned:= srcReg.assigned;
  used    := srcReg.used;
  typ     := srcReg.typ;
end;

{ TxpElement }
function TxpElement.AddElement(elem: TxpElement): TxpElement;
{Agrega un elemento hijo al elemento actual. Devuelve referencia. }
begin
  elem.Parent := self;  //actualzia referencia
  elements.Add(elem);   //agrega a la lista de nombres
  Result := elem;       //no tiene mucho sentido
end;
function TxpElement.FindIdxElemName(const eName: string; var idx0: integer): boolean;
{Busca un nombre en su lista de elementos. Inicia buscando desde idx0, hasta el inicio.
 Si encuentra, devuelve TRUE y deja en idx0, la posición en donde se encuentra.}
var
  i: Integer;
  uName: String;
begin
  uName := upcase(eName);
  //empieza la búsqueda en "idx0"
  for i := idx0 downto 0 do begin
    if upCase(elements[i].name) = uName then begin
      //sale dejando idx0 en la posición encontrada
      idx0 := i;
      exit(true);
    end;
  end;
  exit(false);
end;
function TxpElement.LastNode: TxpElement;
{Devuelve una referencia al último nodo de "elements"}
begin
  if elements = nil then exit(nil);
  if elements.Count = 0 then exit(nil);
  Result := elements[elements.Count-1];
end;
function TxpElement.BodyNode: TxpEleBody;
{Devuelve la referecnia al cuerpo del programa. Aplicable a nodos de tipo función o
"Main". Si no lo encuentra, devuelve NIL.}
var
  elem: TxpElement;
begin
  elem := LastNode;   //Debe ser el último
  if elem.idClass <> eltBody then begin
    exit(nil);  //No deberría pasar
  end;
  //Devuelve referencia
  Result := TxpEleBody(elem);
end;
function TxpElement.Index: integer;
{Devuelve la ubicación del elemento, dentro de su nodo padre.}
begin
  Result := Parent.elements.IndexOf(self);  //No es muy rápido
end;
//Gestion de llamadas al elemento
function TxpElement.AddCaller: TxpEleCaller;
{Agrega información sobre el elemento "llamador", es decir, la función/cuerpo que hace
referencia a este elemento.}
begin
  {Lo maneja a través de evento, para poder acceder a información, del elemento actual
  y datos adicionales, a los que no se tiene acceso desde el contexto de esta clase.}
  if OnAddCaller<>nil then begin
    Result := OnAddCaller(self);
  end else begin
    Result := nil;
  end;
end;
function TxpElement.nCalled: integer;
begin
  Result := lstCallers.Count;
end;
function TxpElement.IsCalledBy(callElem: TxpElement): boolean;
{Indica si el elemento es llamado por "callElem". Puede haber varias llamadas desde
"callElem", pero basta que haya una para devolver TRUE.}
var
  cal : TxpEleCaller;
begin
  for cal in lstCallers do begin
    if cal.caller = callElem then exit(true);
  end;
  exit(false);
end;
function TxpElement.IsCAlledAt(callPos: TSrcPos): boolean;
{Indica si el elemento es llamado, desde la posición indicada.}
var
  cal : TxpEleCaller;
begin
  for cal in lstCallers do begin
    if cal.curPos.EqualTo(callPos) then exit(true);
  end;
  exit(false);
end;
function TxpElement.IsDeclaredAt(decPos: TSrcPos): boolean;
begin
  Result := srcDec.EqualTo(decPos);
end;
function TxpElement.FindCalling(callElem: TxpElement): TxpEleCaller;
{Busca la llamada de un elemento. Si no lo encuentra devuelve NIL.}
var
  cal : TxpEleCaller;
begin
  for cal in lstCallers do begin
    if cal.caller = callElem then exit(cal);
  end;
  exit(nil);
end;
function TxpElement.RemoveCallsFrom(callElem: TxpElement): integer;
{Elimina las referencias de llamadas desde un elemento en particular.
Devuelve el número de referencias eliminadas.}
var
  cal : TxpEleCaller;
  n, i: integer;
begin
  {La búsqueda debe hacerse al revés para evitar el problema de borrar múltiples
  elementos}
  n := 0;
  for i := lstCallers.Count-1 downto 0 do begin
    cal := lstCallers[i];
    if cal.caller = callElem then begin
      lstCallers.Delete(i);
      inc(n);
    end;
  end;
  Result := n;
end;
procedure TxpElement.ClearCallers;
begin
  lstCallers.Clear;
end;
function TxpElement.DuplicateIn(list: TxpElements): boolean;
{Debe indicar si el elemento está duplicado en la lista de elementos proporcionada.}
var
  uName: String;
  ele: TxpElement;
begin
  uName := upcase(name);
  for ele in list do begin
    if upcase(ele.name) = uName then begin
      exit(true);
    end;
  end;
  exit(false);
end;
function TxpElement.Path: string;
{Devuelve una cadena, que indica la ruta del elemento, dentro del árbol de sintaxis.}
var
  ele: TxpElement;
begin
  ele := self;
  Result := '';
  while ele<>nil do begin
    Result := '\' + ele.name + Result;
    ele := ele.Parent;
  end;
end;
constructor TxpElement.Create;
begin
  idClass := eltNone;
  lstCallers:= TxpListCallers.Create(true);
end;
destructor TxpElement.Destroy;
begin
  lstCallers.Destroy;
  elements.Free;  //por si contenía una lista
  inherited Destroy;
end;
function TxpElement.posXYin(const posXY: TPoint): boolean;
{Indica si la coordeda del cursor, se encuentra dentro de las coordenadas del elemento.}
var
  y1, y2: integer;
begin
  y1 := srcDec.row;
  y2 := srcEnd.row;
  //Primero verifica la fila
  if (posXY.y >= y1) and (posXY.y<=y2) then begin
    //Está entre las filas. Pero hay que ver también las columnas, si posXY, está
    //en los bordes.
    if y1 = y2 then begin
      //Es rango es de una sola fila
      if (posXY.X > srcDec.col) and (posXY.X < srcEnd.col) then begin
        exit(true)
      end else begin
        exit(false);
      end;
    end else if posXY.y = y1 then begin
      //Está en el límite superior
      if posXY.X > srcDec.col then begin
        exit(true)
      end else begin
        exit(false);
      end;
    end else if posXY.y = y2 then begin
      //Está en el límite inferior
      if posXY.X < srcEnd.col then begin
        exit(true)
      end else begin
        exit(false);
      end;
    end else begin
      //Está entre los límites
      exit(true);
    end;
  end else begin
    //Esta fuera del rango
    exit(false);
  end;
end;
{ TxpEleMain }
constructor TxpEleMain.Create;
begin
  inherited;
  idClass:=eltMain;
  Parent := nil;  //la raiz no tiene padre
end;
{ TxpEleCon }
constructor TxpEleCon.Create;
begin
  inherited;
  idClass:=eltCons;
end;
{ TxpEleVar }
function TxpEleVar.GetHavAdicPar: boolean;
begin
  Result := adicPar.isAbsol;  //De momento, es el único parámetro adicional
end;
function TxpEleVar.Gettyp: TxpEleType;
begin
  if ftyp.copyOf<>nil then Result := ftyp.copyOf else Result := ftyp;
end;
procedure TxpEleVar.Settyp(AValue: TxpEleType);
begin
  ftyp := AValue;
end;
procedure TxpEleVar.SetHavAdicPar(AValue: boolean);
begin
  adicPar.isAbsol := Avalue;  //De momento, es el único parámetro adicional
end;
function TxpEleVar.AbsAddr: word;
{Devuelve la dirección absoluta de la variable. Tener en cuenta que la variable, no
siempre tiene un solo byte, así que se trata de devolver siempre la dirección del
byte de menor peso.}
begin
  if typ.catType = tctAtomic then begin
    //Tipo básico
    if (typ = typBit) or (typ = typBool) then begin
      Result := adrBit.AbsAdrr;
    end else if (typ = typByte) or (typ = typChar) then begin
      Result := adrByte0.AbsAdrr;
    end else if (typ = typWord) or (typ = typDWord) then begin
      Result := adrByte0.AbsAdrr;
    end else begin
      Result := ADRR_ERROR;
    end;
  end else if typ.catType = tctArray then begin
    //Arreglos
    if (typ.refType = typByte) or (typ.refType = typChar) then begin
      Result := adrByte0.AbsAdrr;
    end else if (typ.refType = typWord) then begin
      Result := adrByte0.AbsAdrr;
    end else begin
      Result := ADRR_ERROR;
    end;
  end else begin
    //No soportado
    Result := ADRR_ERROR;
  end;
end;
function TxpEleVar.AbsAddrL: word;
{Dirección absoluta de la variable de menor pero, cuando es de tipo WORD.}
begin
  if typ.catType = tctAtomic then begin
    if (typ = typWord) or (typ = typDWord) then begin
      Result := adrByte0.AbsAdrr;
    end else begin
      Result := ADRR_ERROR;
    end;
  end else begin
    //No soportado
    Result := ADRR_ERROR;
  end;
end;
function TxpEleVar.AbsAddrH: word;
{Dirección absoluta de la variable de mayor pero, cuando es de tipo WORD.}
begin
  if typ.catType = tctAtomic then begin
    if (typ = typWord) or (typ = typDWord) then begin
      Result := adrByte1.AbsAdrr;
    end else begin
      Result := ADRR_ERROR;
    end;
  end else begin
    //No soportado
    Result := ADRR_ERROR;
  end;
end;
function TxpEleVar.AbsAddrE: word;
begin
  if typ.catType = tctAtomic then begin
    if (typ = typDWord) then begin
      Result := adrByte2.AbsAdrr;
    end else begin
      Result := ADRR_ERROR;
    end;
  end else begin
    //No soportado
    Result := ADRR_ERROR;
  end;
end;
function TxpEleVar.AbsAddrU: word;
begin
  if typ.catType = tctAtomic then begin
    if (typ = typDWord) then begin
      Result := adrByte3.AbsAdrr;
    end else begin
      Result := ADRR_ERROR;
    end;
  end else begin
    //No soportado
    Result := ADRR_ERROR;
  end;
end;
function TxpEleVar.AddrString: string;
{Devuelve una cadena, que representa a la dirección física.}
begin
  if typ.IsBitSize then begin
    Result := 'bnk'+ IntToStr(adrBit.bank) + ':$' + IntToHex(adrBit.offs, 3) + '.' + IntToStr(adrBit.bit);
  end else if typ.IsByteSize then begin
    Result := 'bnk'+ IntToStr(adrByte0.bank) + ':$' + IntToHex(adrByte0.offs, 3);
  end else if typ.IsWordSize then begin
    Result := 'bnk'+ IntToStr(adrByte0.bank) + ':$' + IntToHex(adrByte0.offs, 3);
  end else if typ.IsDWordSize then begin
    Result := 'bnk'+ IntToStr(adrByte0.bank) + ':$' + IntToHex(adrByte0.offs, 3);
  end else begin
    Result := '';   //Error
  end;
end;
function TxpEleVar.BitMask: byte;
{Devuelve la máscara, de acuerdo a su valor de "bit".}
begin
  Result := 0;
  case adrBit.bit of
  0: Result := %00000001;
  1: Result := %00000010;
  2: Result := %00000100;
  3: Result := %00001000;
  4: Result := %00010000;
  5: Result := %00100000;
  6: Result := %01000000;
  7: Result := %10000000;
  end;
end;
procedure TxpEleVar.ResetAddress;
begin
  adrBit.bank := 0;
  adrBit.offs := 0;
  adrBit.bit := 0;

  adrByte0.bank := 0;
  adrByte0.offs := 0;

  adrByte1.bank := 0;
  adrByte1.offs := 0;

  adrByte2.bank := 0;
  adrByte2.offs := 0;

  adrByte3.bank := 0;
  adrByte3.offs := 0;

end;
constructor TxpEleVar.Create;
begin
  inherited;
  idClass:=eltVar;
  adrBit:= TPicRegisterBit.Create;  //
  adrByte0:= TPicRegister.Create;
  adrByte1:= TPicRegister.Create;
  adrByte2:= TPicRegister.Create;
  adrByte3:= TPicRegister.Create;
end;
destructor TxpEleVar.Destroy;
begin
  adrByte0.Destroy;
  adrByte1.Destroy;
  adrByte2.Destroy;
  adrByte3.Destroy;
  adrBit.Destroy;
  inherited Destroy;
end;

{ TxpOperator }
function TxpOperator.CreateOperation(OperandType: TxpEleType;
  proc: TProcExecOperat): TxpOperation;
var
  r: TxpOperation;
begin
  //agrega
  r := TxpOperation.Create;
  r.OperatType:=OperandType;
  r.proc:=proc;
  //agrega
  operations.Add(r);
  Result := r;
end;
function TxpOperator.FindOperation(typ0: TxpEleType): TxpOperation;
{Busca, si encuentra definida, alguna operación, de este operador con el tipo indicado.
Si no lo encuentra devuelve NIL}
var
  r: TxpOperation;
begin
  Result := nil;
  for r in Operations do begin
    if r.OperatType = typ0 then begin
      exit(r);
    end;
  end;
end;
constructor TxpOperator.Create;
begin
  Operations := TxpOperations.Create(true);
end;
destructor TxpOperator.Destroy;
begin
  Operations.Free;
  inherited Destroy;
end;

{ TxpEleType }
function TxpEleType.CreateBinaryOperator(txt: string; prec: byte; OpName: string
  ): TxpOperator;
{Permite crear un nuevo ooperador binario soportado por este tipo de datos. Si hubiera
error, devuelve NIL. En caso normal devuelve una referencia al operador creado}
var
  r: TxpOperator;  //operador
begin
  //verifica nombre
  if FindBinaryOperator(txt)<>nullOper then begin
    Result := nil;  //indica que hubo error
    exit;
  end;
  //Crea y configura objeto
  r := TxpOperator.Create;
  r.txt:=txt;
  r.prec:=prec;
  r.name:=OpName;
  r.kind:=opkBinary;
  //Agrega operador
  Operators.Add(r);
  Result := r;
  //Verifica si es el operador de asignación
  if txt = ':=' then begin
    //Lo guarda porque este operador se usa y no vale la pena buscarlo
    operAsign := r;
  end;
end;
function TxpEleType.CreateUnaryPreOperator(txt: string; prec: byte; OpName: string;
  proc: TProcExecOperat): TxpOperator;
{Crea operador unario de tipo Pre, para este tipo de dato.}
var
  r: TxpOperator;  //operador
begin
  //Crea y configura objeto
  r := TxpOperator.Create;
  r.txt:=txt;
  r.prec:=prec;
  r.name:=OpName;
  r.kind:=opkUnaryPre;
  r.OperationPre:=proc;
  //Agrega operador
  Operators.Add(r);
  Result := r;
end;
function TxpEleType.CreateUnaryPostOperator(txt: string; prec: byte; OpName: string;
  proc: TProcExecOperat): TxpOperator;
{Crea operador binario de tipo Post, para este tipo de dato.}
var
  r: TxpOperator;  //operador
begin
  //Crea y configura objeto
  r := TxpOperator.Create;
  r.txt:=txt;
  r.prec:=prec;
  r.name:=OpName;
  r.kind:=opkUnaryPost;
  r.OperationPost:=proc;
  //Agrega operador
  Operators.Add(r);
  Result := r;
end;
function TxpEleType.FindBinaryOperator(const OprTxt: string): TxpOperator;
{Recibe el texto de un operador y devuelve una referencia a un objeto TxpOperator, del
tipo. Si no está definido el operador para este tipo, devuelve nullOper.}
var
  oper: TxpOperator;
begin
//  if copyOf<>nil then begin  //Es copia, pasa a la copia
//    exit(copyOf.FindBinaryOperator(OprTxt));
//  end;
  /////////////////////////////////////////////////////////
  Result := nullOper;   //valor por defecto
  for oper in Operators do begin
    if (oper.kind = opkBinary) and (oper.txt = upCase(OprTxt)) then begin
      exit(oper); //está definido
    end;
  end;
  //No encontró
  Result.txt := OprTxt;    //para que sepa el operador leído
end;
function TxpEleType.FindUnaryPreOperator(const OprTxt: string): TxpOperator;
{Recibe el texto de un operador unario Pre y devuelve una referencia a un objeto
TxpOperator, del tipo. Si no está definido el operador para este tipo, devuelve nullOper.}
var
  oper: TxpOperator;
begin
//  if copyOf<>nil then begin  //Es copia, pasa a la copia
//    exit(copyOf.FindUnaryPreOperator(OprTxt));
//  end;
  /////////////////////////////////////////////////////////
  Result := nullOper;   //valor por defecto
  for oper in Operators do begin
    if (oper.kind = opkUnaryPre) and (oper.txt = upCase(OprTxt)) then begin
      exit(oper); //está definido
    end;
  end;
  //no encontró
  Result.txt := OprTxt;    //para que sepa el operador leído
end;
function TxpEleType.FindUnaryPostOperator(const OprTxt: string): TxpOperator;
{Recibe el texto de un operador unario Post y devuelve una referencia a un objeto
TxpOperator, del tipo. Si no está definido el operador para este tipo, devuelve nullOper.}
var
  oper: TxpOperator;
begin
//  if copyOf<>nil then begin  //Es copia, pasa a la copia
//    exit(copyOf.FindUnaryPostOperator(OprTxt));
//  end;
  /////////////////////////////////////////////////////////
  Result := nullOper;   //valor por defecto
  for oper in Operators do begin
    if (oper.kind = opkUnaryPost) and (oper.txt = upCase(OprTxt)) then begin
      exit(oper); //está definido
    end;
  end;
  //no encontró
  Result.txt := OprTxt;    //para que sepa el operador leído
end;
procedure TxpEleType.SaveToStk;
begin
  if OnSaveToStk<>nil then OnSaveToStk;
end;

procedure TxpEleType.CreateField(metName: string; proc: TTypFieldProc);
{Crea una función del sistema. A diferencia de las funciones definidas por el usuario,
una función del sistema se crea, sin crear espacios de nombre. La idea es poder
crearlas rápidamente.}
var
  fun : TTypField;
begin
  fun := TTypField.Create;  //Se crea como una función normal
  fun.Name := metName;
  fun.proc := proc;
//no verifica duplicidad
  fields.Add(fun);
end;
function TxpEleType.IsBitSize: boolean;
{Indica si el tipo, tiene 1 bit de tamaño}
begin
//  if copyOf<>nil then exit(copyOf.IsBitSize);  //verifica
  Result := (self = typBit) or (self = typBool);
end;
function TxpEleType.IsByteSize: boolean;
{Indica si el tipo, tiene 1 byte de tamaño}
begin
//  if copyOf<>nil then exit(copyOf.IsByteSize);  //verifica
  Result := (self = typByte) or (self = typChar);
end;
function TxpEleType.IsWordSize: boolean;
{Indica si el tipo, tiene 2 bytes de tamaño}
begin
//  if copyOf<>nil then exit(copyOf.IsWordSize);  //verifica
  Result := (self = typWord);
end;
function TxpEleType.IsDWordSize: boolean;
{Indica si el tipo, tiene 4 bytes de tamaño}
begin
//  if copyOf<>nil then exit(copyOf.IsDWordSize);  //verifica
  Result := (self = typDWord);
end;
procedure TxpEleType.DefineRegister;
{Define los registros que va a usar el tipo de dato.}
begin
  if OnDefineRegister<>nil then OnDefineRegister;
end;
constructor TxpEleType.Create;
begin
  inherited;
  idClass:=eltType;
  //Crea lista de campos
  fields:= TTypFields.Create(true);
  //Ceea lista de operadores
  Operators := TxpOperators.Create(true);  //Lista de operadores aplicables a este tipo
end;
destructor TxpEleType.Destroy;
begin
  Operators.Destroy;
  fields.Destroy;
  inherited;
end;
{ TxpEleFun }
procedure TxpEleFun.ClearParams;
//Elimina los parámetros de una función
begin
  setlength(pars,0);
end;
procedure TxpEleFun.CreateParam(parName: string; typ0: TxpEleType; pvar: TxpEleVar);
//Crea un parámetro para la función
var
  n: Integer;
begin
  //agrega
  n := high(pars)+1;
  setlength(pars, n+1);
  pars[n].name := parName;
  pars[n].typ  := typ0;  //agrega referencia
  pars[n].pvar := pvar;
end;
function TxpEleFun.SameParams(Fun2: TxpEleFun): boolean;
{Compara los parámetros de la función con las de otra. Si tienen el mismo número
de parámetros y el mismo tipo, devuelve TRUE.}
var
  i: Integer;
begin
  Result:=true;  //se asume que son iguales
  if High(pars) <> High(Fun2.pars) then
    exit(false);   //distinto número de parámetros
  //hay igual número de parámetros, verifica
  for i := 0 to High(pars) do begin
    if pars[i].typ <> Fun2.pars[i].typ then begin
      exit(false);
    end;
  end;
  //si llegó hasta aquí, hay coincidencia, sale con TRUE
end;
function TxpEleFun.ParamTypesList: string;
{Devuelve una lista con los nombres de los tipos de los parámetros, de la forma:
(byte, word) }
var
  tmp: String;
  j: Integer;
begin
  tmp := '';
  for j := 0 to High(pars) do begin
    tmp += pars[j].name+', ';
  end;
  //quita coma final
  if length(tmp)>0 then tmp := copy(tmp,1,length(tmp)-2);
  Result := '('+tmp+')';
end;
function TxpEleFun.DuplicateIn(list: TxpElements): boolean;
var
  uName: String;
  ele: TxpElement;
begin
  uName := upcase(name);
  for ele in list do begin
    if ele = self then Continue;  //no se compara el mismo
    if upcase(ele.name) = uName then begin
      //hay coincidencia de nombre
      if ele.idClass = eltFunc then begin
        //para las funciones, se debe comparar los parámetros
        if SameParams(TxpEleFun(ele)) then begin
          exit(true);
        end;
      end else begin
        //si tiene el mismo nombre que cualquier otro elemento, es conflicto
        exit(true);
      end;
    end;
  end;
  exit(false);
end;
procedure TxpEleFun.SetElementsUnused;
{Marca todos sus elementos con "nCalled = 0". Se usa cuando se determina que una función
no es usada.}
var
  elem: TxpElement;
begin
  if elements = nil then exit;  //No tiene
  //Marca sus elementos, como no llamados
  for elem in elements do begin
    elem.ClearCallers;
    if elem.idClass = eltVar then begin
      TxpEleVar(elem).ResetAddress;
    end;
  end;
end;
constructor TxpEleFun.Create;
begin
  inherited;
  idClass:=eltFunc;
end;

{ TxpEleUnit }
constructor TxpEleUnit.Create;
begin
  inherited;
  idClass:=eltUnit;
end;
{ TxpEleBody }
constructor TxpEleBody.Create;
begin
  inherited;
  idClass := eltBody;
end;
{ TxpEleDIREC }
constructor TxpEleDIREC.Create;
begin
  inherited Create;
  idClass := eltBody;
end;
{ TXpTreeElements }
procedure TXpTreeElements.Clear;
begin
  main.elements.Clear;  //esto debe hacer un borrado recursivo
  curNode := main;      //retorna al nodo principal
  //ELimina lista internas
  AllVars.Clear;
  AllFuncs.Clear;
end;
procedure TXpTreeElements.RefreshAllVars;
{Devuelve una lista de todas las variables del árbol de sintaxis, incluyendo las de las
funciones y procedimientos. La lista se obtiene ordenada de acuerdo a como se haría en
una exploración sintáctica normal.}
  procedure AddVars(nod: TxpElement);
  var
    ele : TxpElement;
  begin
    if nod.elements<>nil then begin
      for ele in nod.elements do begin
        if ele.idClass = eltVar then begin
          AllVars.Add(TxpEleVar(ele));
        end else begin
          if ele.elements<>nil then
            AddVars(ele);  //recursivo
        end;
      end;
    end;
  end;
begin
  AllVars.Clear;   //por si estaba llena
  AddVars(main);
end;
procedure TXpTreeElements.RefreshAllFuncs;
{Actualiza una lista de todas las funciones del árbol de sintaxis, incluyendo las de las
unidades.}
  procedure AddFuncs(nod: TxpElement);
  var
    ele : TxpElement;
  begin
    if nod.elements<>nil then begin
      for ele in nod.elements do begin
        if ele.idClass = eltFunc then begin
          AllFuncs.Add(TxpEleFun(ele));
        end else begin
          if ele.elements<>nil then
            AddFuncs(ele);  //recursivo
        end;
      end;
    end;
  end;
begin
  AllFuncs.Clear;   //por si estaba llena
  AddFuncs(main);
end;
function TXpTreeElements.CurNodeName: string;
{Devuelve el nombre del nodo actual}
begin
  Result := curNode.name;
end;
function TXpTreeElements.LastNode: TxpElement;
{Devuelve una referencia al último nodo de "main"}
begin
  Result := main.LastNode;
end;
function TXpTreeElements.BodyNode: TxpEleBody;
{Devuelve la referecnia al cuerpo principal del programa.}
begin
  Result := main.BodyNode;
end;
//funciones para llenado del arbol
function TXpTreeElements.AddElement(elem: TxpElement; verifDuplic: boolean = true): boolean;
{Agrega un elemento al nodo actual. Si ya existe el nombre del nodo, devuelve false.
Este es el punto único de entrada para realizar cambios en el árbol.}
begin
  Result := true;
  //Verifica si hay conflicto. Solo es necesario buscar en el nodo actual.
  if verifDuplic and elem.DuplicateIn(curNode.elements) then begin
    exit(false);  //ya existe
  end;
  //Agrega el nodo
  curNode.AddElement(elem);
  if OnAddElement<>nil then OnAddElement(elem);
end;
procedure TXpTreeElements.AddElementAndOpen(elem: TxpElement);
{Agrega un elemento y cambia el nodo actual al espacio de este elemento nuevo. Este
método está reservado para las funciones o procedimientos}
begin
  {las funciones o procedimientos no se validan inicialmente, sino hasta que
  tengan todos sus parámetros agregados, porque pueden ser sobrecargados.}
  AddElement(elem, false);
  //Genera otro espacio de nombres
  elem.elements := TxpElements.Create(true);  //su propia lista
  curNode := elem;  //empieza a trabajar en esta lista
end;
procedure TXpTreeElements.OpenElement(elem: TxpElement);
{Accede al espacio de nombres del elemento indicado.}
begin
  curNode := elem;  //empieza a trabajar en esta lista
end;
function TXpTreeElements.ValidateCurElement: boolean;
{Este método es el complemento de OpenElement(). Se debe llamar cuando ya se
 tienen creados los parámetros de la función o procedimiento, para verificar
 si hay duplicidad, en cuyo caso devolverá FALSE}
begin
  //Se asume que el nodo a validar ya se ha abierto, con OpenElement() y es el actual
  if curNode.DuplicateIn(curNode.Parent.elements) then begin  //busca en el nodo anterior
    exit(false);
  end else begin
    exit(true);
  end;
end;
procedure TXpTreeElements.CloseElement;
{Sale del nodo actual y retorna al nodo padre}
begin
  if curNode.Parent<>nil then
    curNode := curNode.Parent;
end;
//Métodos para identificación de nombres
function TXpTreeElements.FindNext: TxpElement;
{Realiza una búsqueda recursiva en el nodo "curFindNode", a partir de la posición,
"curFindIdx", hacia "atrás", el elemento con nombre "curFindName". También implementa
la búsqueda en unidades.
Esta rutina es quien define la resolución de nombres (alcance) en PicPas.}
var
  tmp: String;
  elem: TxpElement;
begin
//  debugln(' Explorando nivel: [%s] en pos: %d', [curFindNode.name, curFindIdx - 1]);
  tmp := UpCase(curFindName);  //convierte pra comparación
  repeat
    curFindIdx := curFindIdx - 1;  //Siempre salta a la posición anterior
    if curFindIdx<0 then begin
      //No encontró, en ese nivel. Hay que ir más atrás. Pero esto se resuelve aquí.
      if curFindNode.Parent = nil then begin
        //No hay nodo padre. Este es el nodo Main
        Result := nil;
        exit;  //aquí termina la búsqueda
      end;
      //Busca en el espacio padre
      curFindIdx := curFindNode.Index;  //posición actual
      curFindNode := curFindNode.Parent;  //apunta al padre
      if inUnit then inUnit := false;   //Sale de una unidad
      Result := FindNext();  //Recursividad IMPORTANTE: Usar paréntesis.
//      Result := nil;
      exit;
    end;
    //Verifica ahora este elemento
    elem := curFindNode.elements[curFindIdx];
    if UpCase(elem.name) = tmp then begin
      //Encontró en "curFindIdx"
      Result := elem;
      //La siguiente búsqueda empezará en "curFindIdx-1".
      exit;
    end else begin
      //No tiene el mismo nombre, a lo mejor es una unidad
      if (elem.idClass = eltUnit) and not inUnit then begin   //Si es el priemr nodo de unidad
        //¡Diablos es una unidad! Ahora tenemos que implementar la búsqueda.
        inUnit := true;   //Marca, para que solo busque en un nivel
        curFindIdx := elem.elements.Count;  //para que busque desde el último
        curFindNode := elem;  //apunta a la unidad
        Result := FindNext();  //Recursividad IMPORTANTE: Usar paréntesis.
        if Result <> nil then begin  //¿Ya encontró?
          exit;  //Sí. No hay más que hacer aquí
        end;
        //No encontró. Hay que seguir buscando
      end;
    end;
  until false;
end;
function TXpTreeElements.FindFirst(const name: string): TxpElement;
{Rutina que permite resolver un identificador dentro del árbol de sintaxis, siguiendo las
reglas de alcance de identificacdores (primero en el espacio actual y luego en los
espacios padres).
Si encuentra devuelve la referencia. Si no encuentra, devuelve NIL}
begin
  //Busca recursivamente, a partir del espacio actual
  curFindName := name;     //Este valor no cambiará en toda la búsqueda
  inUnit := false;     //Inicia bandera
  if curNode.idClass = eltBody then begin
    {Para los cuerpos de procemientos o de programa, se debe explorar hacia atrás a
    partir de la posición del nodo actual.}
    curFindIdx := curNode.Index;  //Ubica posición
    curFindNode := curNode.Parent;  //Actualiza nodo actual de búsqueda
    Result := FindNext;
  end else begin
    {La otras forma de resolución, debe ser:
    1. Declaración de constantes, cuando se definen como expresión con otras constantes
    2. Declaración de variables, cuando se definen como ABSOLUTE <variable>
    3. Declaración de variables, cuando se definen de un tipo definido en TYPES.
    }
    curFindNode := curNode;  //Actualiza nodo actual de búsqueda
    {Formalmente debería apuntar a la posición del elemento actual, pero se deja
    apuntando a la posición final, sin peligro, porque, la resolución de nombres para
    constantes y variables, se hace solo en la primera pasada (con el árbol de sintaxis
    llenándose.)}
    curFindIdx := curNode.elements.Count;
    //Busca
    Result := FindNext;
  end;
end;
function TXpTreeElements.FindNextFunc: TxpEleFun;
{Explora recursivamente haciá la raiz, en el arbol de sintaxis, hasta encontrar el nombre
de la fución indicada. Debe llamarse después de FindFirst().
Si no enecuentra devuelve NIL.}
var
  ele: TxpElement;
begin
  repeat
    ele := FindNext;
  until (ele=nil) or (ele.idClass = eltFunc);
  //Puede que haya encontrado la función o no
  if ele = nil then exit(nil);  //No encontró
  Result := TxpEleFun(ele);   //devuelve como función
end;
function TXpTreeElements.FindVar(varName: string): TxpEleVar;
{Busca una variable con el nombre indicado en el espacio de nombres actual}
var
  ele : TxpElement;
  uName: String;
begin
  uName := upcase(varName);
  for ele in curNode.elements do begin
    if (ele.idClass = eltVar) and (upCase(ele.name) = uName) then begin
      Result := TxpEleVar(ele);
      exit;
    end;
  end;
  exit(nil);
end;
function TXpTreeElements.GetElementBodyAt(posXY: TPoint): TxpEleBody;
{Busca el elemento del arbol, dentro del nodo principal, y sus nodos hijos, en que
cuerpo (nodo Body) se encuentra la coordenada del cursor "posXY".
Si no encuentra, devuelve NIL.}
var
  res: TxpEleBody;

  procedure ExploreForBody(nod: TxpElement);
  var
    ele : TxpElement;
  begin
    if nod.elements<>nil then begin
      //Explora a todos sus elementos
      for ele in nod.elements do begin
        if ele.idClass = eltBody then begin
          //Encontró un Body, verifica
          if ele.posXYin(posXY) then begin
            res := TxpEleBody(ele);   //guarda referencia
            exit;
          end;
        end else begin
          //No es un body, puede ser un eleemnto con nodos hijos
          if ele.elements<>nil then
            ExploreForBody(ele);  //recursivo
        end;
      end;
    end;
  end;
begin
  //Realiza una búsqueda recursiva.
  res := nil;   //Por defecto
  ExploreForBody(main);
  Result := res;
end;
function TXpTreeElements.GetElementCalledAt(const srcPos: TSrcPos): TxpElement;
{Explora los elementos, para ver si alguno es llamado desde la posición indicada.
Si no lo encuentra, devueleve NIL.}
var
  res: TxpElement;

  procedure ExploreForCall(nod: TxpElement);
  var
    ele : TxpElement;
  begin
    if nod.elements<>nil then begin
      //Explora a todos sus elementos
      for ele in nod.elements do begin
        if ele.IsCAlledAt(srcPos) then begin
            res := ele;   //guarda referencia
            exit;
        end else begin
          //No es un body, puede ser un eleemnto con nodos hijos
          if ele.elements<>nil then
            ExploreForCall(ele);  //recursivo
        end;
      end;
    end;
  end;
begin
  //Realiza una búsqueda recursiva.
  res := nil;   //Por defecto
  ExploreForCall(main);
  Result := res;
end;
function TXpTreeElements.GetELementDeclaredAt(const srcPos: TSrcPos): TxpElement;
{Explora los elementos, para ver si alguno es declarado en la posición indicada.}
var
  res: TxpElement;

  procedure ExploreForDec(nod: TxpElement);
  var
    ele : TxpElement;
  begin
    if nod.elements<>nil then begin
      //Explora a todos sus elementos
      for ele in nod.elements do begin
        if ele.IsDeclaredAt(srcPos) then begin
            res := ele;   //guarda referencia
            exit;
        end else begin
          //No es un body, puede ser un eleemnto con nodos hijos
          if ele.elements<>nil then
            ExploreForDec(ele);  //recursivo
        end;
      end;
    end;
  end;
begin
  //Realiza una búsqueda recursiva.
  res := nil;   //Por defecto
  ExploreForDec(main);
  Result := res;
end;

//constructor y destructor
constructor TXpTreeElements.Create;
begin
  main:= TxpEleMain.Create;  //No debería
  main.name := 'Main';
  main.elements := TxpElements.Create(true);  //debe tener lista
  AllFuncs := TxpEleFuns.Create(false);   //Crea lista
  AllVars := TxpEleVars.Create(false);   //Crea lista
  curNode := main;  //empieza con el nodo principal como espacio de nombres actual
end;
destructor TXpTreeElements.Destroy;
begin
  main.Destroy;
  AllVars.Free;    //por si estaba creada
  AllFuncs.Free;
  inherited Destroy;
end;
initialization
  //crea el operador NULL
  nullOper := TxpOperator.Create;

finalization
  nullOper.Free;
end.

