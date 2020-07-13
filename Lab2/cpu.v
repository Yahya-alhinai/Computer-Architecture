//////////////////////////////////////////////////////////////////////////////////
`timescale 1ns / 1ps

//the CPU module from 4.13.4 of the textbook from the online companion material
//The initial register and memory state are read from .dat files and the
//resulting register and memory state are each printed into corresponding .dat
//files

module CPU (clock);
    input clock;

    parameter LW = 6'b100011;
    parameter SW = 6'b101011;
    parameter BEQ = 6'b000100;
    parameter no_op = 32'b0000000_0000000_0000000_0000000;
    parameter ALUop = 6'b0;
    parameter bpdcr = 6'b100010;
    parameter BNE = 6'b000101;

    integer fd, code, str, t;


    reg [31:0] PC;
    reg [31:0] Regs[0:31];
    reg [31:0] IMemory[0:1023];
    reg [31:0] DMemory[0:1023]; // separate memories


    reg [31:0] IFIDIR;
    reg [31:0] IDEXA;
    reg [31:0] IDEXB;
    reg [31:0] IDEXIR;
    reg [31:0] EXMEMIR;
    reg [31:0] EXMEMB; // pipeline registers

//---------------------------------------------------[ADD REG]-----------------------------------------------------//
    reg [31:0] EXMEMSH;
    reg FLAG = 0;
//-----------------------------------------------------------------------------------------------------------------//
    
    reg [31:0] EXMEMALUOut;
    reg [31:0] MEMWBValue;
    reg [31:0] MEMWBIR; // pipeline registers

    wire [4:0] IDEXrs, IDEXrt, IDEXsh, EXMEMrd, MEMWBrd, EXMEMrt, IFIDrs, IFIDrt; //hold register fields
    wire [5:0] EXMEMop, MEMWBop, IDEXop, IFIDop; //Hold opcodes
    wire [31:0] Ain, Bin, SHin;

    //declare the bypass signals
    wire takebranch, stall, bypassAfromMEM, bypassAfromALUinWB,bypassBfromMEM, bypassBfromALUinWB, bypassSHfromMEM, bypassSHfromALUinWB, bypassAfromLWinWB, bypassBfromLWinWB, bypassSHfromLWinWB;
    wire bypassIDEXAfromWB, bypassIDEXBfromWB, bypassIDEXSHfromWB;

    assign IDEXrs = IDEXIR[25:21];  assign IDEXrt = IDEXIR[20:16];  assign IDEXsh = IDEXIR[10:6];  assign EXMEMrd = EXMEMIR[15:11]; assign EXMEMrt = EXMEMIR[20:16];
    assign MEMWBrd = MEMWBIR[15:11]; assign EXMEMop = EXMEMIR[31:26];
    assign MEMWBop = MEMWBIR[31:26];  assign IDEXop = IDEXIR[31:26];
    assign IFIDop = IFIDIR[31:26]; assign IFIDrs = IFIDIR[25:21]; assign IFIDrt = IFIDIR[20:16];

    // The bypass to input A from the MEM stage for an ALU operation
    assign bypassAfromMEM = (IDEXrs == EXMEMrd) & (IDEXrs!=0) & (EXMEMop==ALUop); // yes, bypass

    // The bypass to input B from the MEM stage for an ALU operation
    assign bypassBfromMEM = (IDEXrt == EXMEMrd)&(IDEXrt!=0) & (EXMEMop==ALUop); // yes, bypass

////////////////////////////////////////////////////////////////////////////////////////////////////////////
    assign bypassSHfromMEM = (IDEXsh == EXMEMrd) & (IDEXsh!=0) & (EXMEMop==ALUop); // yes, bypass         //
////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // The bypass to input A from the WB stage for an ALU operation
    assign bypassAfromALUinWB = (IDEXrs == MEMWBrd) & (IDEXrs!=0) & (MEMWBop==ALUop);

    // The bypass to input B from the WB stage for an ALU operation
    assign bypassBfromALUinWB = (IDEXrt == MEMWBrd) & (IDEXrt!=0) & (MEMWBop==ALUop);

////////////////////////////////////////////////////////////////////////////////////////////////////////////
    assign bypassSHfromALUinWB = (IDEXsh == MEMWBrd) & (IDEXsh!=0) & (MEMWBop==ALUop); // yes, bypass   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // The bypass to input A from the WB stage for an LW operation
    assign bypassAfromLWinWB = (IDEXrs == MEMWBIR[20:16]) & (IDEXrs!=0) & (MEMWBop==LW);

    // The bypass to input B from the WB stage for an LW operation
    assign bypassBfromLWinWB = (IDEXrt == MEMWBIR[20:16]) & (IDEXrt!=0) & (MEMWBop==LW);

////////////////////////////////////////////////////////////////////////////////////////////////////////////
    assign bypassSHfromLWinWB = (IDEXsh == MEMWBIR[20:16]) & (IDEXsh!=0) & (MEMWBop==LW); // yes, bypass  //
////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // The A input to the ALU is bypassed from MEM if there is a bypass there,
    // Otherwise from WB if there is a bypass there, and otherwise comes from the IDEX register
    assign Ain = bypassAfromMEM? EXMEMALUOut : (bypassAfromALUinWB | bypassAfromLWinWB)? MEMWBValue : IDEXA;

    // The B input to the ALU is bypassed from MEM if there is a bypass there,
    // Otherwise from WB if there is a bypass there, and otherwise comes from the IDEX register
    assign Bin = bypassBfromMEM? EXMEMALUOut : (bypassBfromALUinWB | bypassBfromLWinWB) ? MEMWBValue: IDEXB;

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    assign SHin = bypassSHfromMEM? EXMEMALUOut : (bypassSHfromALUinWB | bypassSHfromLWinWB) ? MEMWBValue: EXMEMSH;   //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    //Forwarding from the WB stage to the decode stage
    assign bypassIDEXAfromWB = (MEMWBIR != no_op) & (IFIDIR != no_op) &
    (((IFIDIR[25:21] == MEMWBIR[20:16]) & (MEMWBop == LW)) | ( (MEMWBop == ALUop | MEMWBop == bpdcr) & (MEMWBrd == IFIDIR[25:21])));

    assign bypassIDEXBfromWB = (MEMWBIR != no_op) & (IFIDIR != no_op) &
    (((IFIDIR[20:16] == MEMWBIR[20:16]) & (MEMWBop == LW)) | ( (MEMWBop == ALUop) & (MEMWBrd == IFIDIR[20:16])));

    assign bypassIDEXSHfromWB = (MEMWBIR != no_op) & (IFIDIR != no_op) &
    (((IFIDIR[10:6] == MEMWBIR[10:6]) & (MEMWBop == LW)) | ( (MEMWBop == ALUop) & (MEMWBrd == IFIDIR[10:6])));
    
    // The signal for detecting a stall based on the use of a result from LW
    assign stall =  (IDEXIR[31:26]==LW) && // source instruction is a load
                    (((IFIDop==LW) && (IFIDrs==IDEXrt)) | // stall for LW address calc
                    ((IFIDop==ALUop) && ((IFIDrs==IDEXrt) | (IFIDrt==IDEXrt))) |  //ALU use
                    ((IFIDop==SW) &&  ((IFIDrs==IDEXrt) | (IFIDrt==IDEXrt))));
//EXMEMIR
    //Signal for a taken branch: instruction is BEQ and registers are equal
    assign takebranch = ((IFIDIR[31:26]==BEQ) && (Regs[IFIDIR[25:21]] == Regs[IFIDIR[20:16]])) |
                        ((IFIDIR[31:26]==BNE) && (Regs[IFIDIR[25:21]] != Regs[IFIDIR[20:16]]));
    
    
    reg [10:0] i; //used to initialize registers
    
    initial
    begin
        t=0;
        #1 //delay of 1, wait for the input ports to initialize
        PC = 0;
        IFIDIR = no_op; IDEXIR = no_op; EXMEMIR = no_op; MEMWBIR = no_op; // put no_ops in pipeline registers
        for (i=0;i<=31;i=i+1) Regs[i]=i; //initialize registers -- just so they aren't don't cares
        for(i=0;i<=1023;i=i+1) IMemory[i]=0;
        for(i=0;i<=1023;i=i+1) DMemory[i]=0;
        fd=$fopen("./regs.dat","r");
        i=0;
        while(!$feof(fd))
        begin
            code=$fscanf(fd, "%b\n", str);
            Regs[i]=str;
            i=i+1;
        end
        i=0; fd=$fopen("./dmem.dat","r");
        while(!$feof(fd))
        begin
            code=$fscanf(fd, "%b\n", str);
            DMemory[i]=str;
            i=i+1;
        end
        i=0; fd=$fopen("./imem.dat","r");
        while(!$feof(fd))
        begin
            code=$fscanf(fd, "%b\n", str);
            IMemory[i]=str;
            i=i+1;
        end
        #396
        i=0; fd =$fopen("./mem_result.dat","w" ); //open memory result file
        while(i < 32)
        begin
            str = DMemory[i];  //dump the first 32 memory values
            $fwrite(fd, "%b\n", str);
            i=i+1;
        end
        $fclose(fd);
        i=0; fd =$fopen("./regs_result.dat","w" ); //open register result file
        while(i < 32)
        begin
            str = Regs[i];  //dump the register values
            $fwrite(fd, "%b\n", str);
            i=i+1;
        end
        $fclose(fd);
    end

    reg [1:0] IFcase = 0;
    reg [31:0] PC_bpdcr = 0;

    always @ (posedge clock)
    begin
        t = t + 1;
        if (~stall)
        begin // the first three pipeline stages stall if there is a load hazard
//---------------------------------------------------[IF]-----------------------------------------------------//
            case(IFcase)
                0: begin
                    if (~takebranch)
                    begin
                        IFIDIR <= IMemory[PC>>2];
                        IFcase <= (IMemory[PC>>2][31:26] == bpdcr) ? 1 : 0;
                        PC <= PC + 4;
                        PC_bpdcr <= (IMemory[PC>>2][31:26] == bpdcr) ? (PC + 4) : 0;
                    end else
                    begin // a taken branch is in ID; instruction in IF is wrong; insert a no_op and reset the PC
                        IFIDIR <= no_op;
                        PC <= PC + ({{16{IFIDIR[15]}}, IFIDIR[15:0]} << 2);
                    end
                end

                1: begin
                    IFIDIR <= no_op;
                    IFcase <= 2;
                end

                2: begin 
                    IFIDIR <= no_op;
                    IFcase <= 0;
                end
        endcase
//------------------------------------------------------------------------------------------------------------//



//---------------------------------------------------[ID]-----------------------------------------------------//
            if (~bypassIDEXAfromWB)
            begin
                IDEXA <= Regs[IFIDIR[25:21]];
            end else
            begin
               IDEXA <= MEMWBValue;
            end

            if (~bypassIDEXBfromWB)
                IDEXB <= Regs[IFIDIR[20:16]]; // get two registers
            else
                IDEXB <= MEMWBValue;

            if (~bypassIDEXSHfromWB)
                EXMEMSH <= Regs[IFIDIR[10:6]]; // get two registers
            else
                EXMEMSH <= MEMWBValue;

            IDEXIR <= IFIDIR;  //pass along IR
        end else
        begin  //Freeze first two stages of pipeline; inject a nop into the ID output
            IDEXIR <= no_op;
        end
//------------------------------------------------------------------------------------------------------------//



//---------------------------------------------------[EX]-----------------------------------------------------//
        //EX stage of the pipeline
        if ((IDEXop==LW) | (IDEXop==SW))  // address calculation & copy B
        begin
            EXMEMALUOut <= Ain + {{16{IDEXIR[15]}}, IDEXIR[15:0]};
        end
        else if (IDEXop==ALUop) // rs ==> Ain  || rt ==> Bin
        begin 
            case (IDEXIR[5:0]) //case for the various R-type instructions
                32: begin //AND
                    EXMEMALUOut <= Ain + Bin;  //add operation
                end

                37: begin //OR
                    EXMEMALUOut <= Ain | Bin;
                end

                42: begin //SLT
                    EXMEMALUOut <= (Ain < Bin);
                end

                4: begin //SLLV
                    EXMEMALUOut <= (Bin << Ain);
                end

                29: begin //Conditional Move
                    if (Ain < Bin)
                        EXMEMALUOut <= SHin;
                    else
                        EXMEMALUOut <= 0;
                end
                default: ; //other R-type operations: subtract, SLT, etc.
            endcase
        end
        else if (IDEXop == bpdcr)
        begin
            if (Ain > 0  & Ain[31] == 0)
            begin
                EXMEMALUOut <=  Ain - 1;
                PC <= PC_bpdcr + ({{16{IDEXIR[15]}}, IDEXIR[15:0]} << 2);
            end else
            begin
                EXMEMALUOut <=  Ain;
            end
        end
        FLAG <= (IDEXop==ALUop & IDEXIR[5:0] == 29 & !(Ain < Bin))? 1 : 0;
        EXMEMIR <= IDEXIR;
        EXMEMB <= Bin; //pass along the IR & B register
//-------------------------------------------------------------------------------------------------------------//


//---------------------------------------------------[MEM]-----------------------------------------------------//
        //MEM stage
        if (EXMEMop == ALUop | EXMEMop == bpdcr) MEMWBValue <= EXMEMALUOut;
        else if (EXMEMop == LW) MEMWBValue <= DMemory[EXMEMALUOut>>2];
        else if (EXMEMop == SW) DMemory[EXMEMALUOut>>2] <= EXMEMB; //store

        MEMWBIR <= (FLAG) ? {MEMWBIR[31:16], 5'b00000, MEMWBIR[10:0]} : EXMEMIR; //pass along IR
//------------------------------------------------------------------------------------------------------------//


//---------------------------------------------------[WB]-----------------------------------------------------//
        //WB stage
        if ((MEMWBop == ALUop) & (MEMWBrd != 0)) Regs[MEMWBrd] <= MEMWBValue; // ALU operation
        else if (MEMWBop == bpdcr) Regs[MEMWBIR[25:21]] <= MEMWBValue;
        else if ((MEMWBop == LW) & (MEMWBIR[20:16] != 0))
        begin
            Regs[MEMWBIR[20:16]] <= MEMWBValue;
        end
//-----------------------------------------------------------------------------------------------------------//
   end
endmodule