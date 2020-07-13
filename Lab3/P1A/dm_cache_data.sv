`timescale 1ns / 1ps

//TODO
//modify the cache so that it 
//is set associative
import cache_def::*; 

/*cache: data memory, single port, 1024 blocks, N WAYS*/
module dm_cache_data(input  bit clk, 
    input  cache_req_type  data_req,//data request/command, e.g. RW, valid
    input  cache_data_type data_write, //write port (128-bit line)
    input int way, 
    output cache_data_type data_read[0:N-1]
    ); //read port
    
    timeunit 1ns; timeprecision 1ps;
    
    cache_data_type data_mem[0:1023][0:N-1];
  
  initial  begin
    for (int i=0; i<1024; i++) 
        begin
            for(int j=0; j < N; j++)
                data_mem[i][j] = 0;
        end
  end
  
  assign data_read = data_mem[data_req.index];
  
//  genvar i;
//  generate
//  for(i=0; i<N; i++) begin
//    assign  data_read[i]  =  data_mem[data_req.index][i];
//  end
//  endgenerate
  
  always_ff  @(posedge(clk))  begin
    if  (data_req.we) begin
      data_mem[data_req.index][way] <= data_write;
      $display("%t: [Cache] write @ index=%x with data=%x", $time, data_req.index, data_write );
      end
  end
endmodule

/*cache: tag memory, single port, 1024 blocks, N WAYS*/
module dm_cache_tag(input  bit clk, //write clock
    input  cache_req_type tag_req, //tag request/command, e.g. RW, valid
    input  cache_tag_type tag_write,//write port
    input int way,    
    output cache_tag_type tag_read [0:N-1]);//read porttag_read
    
  timeunit 1ns; timeprecision 1ps;
  
  cache_tag_type tag_mem[0:1023][0:N-1];
  
  
  initial  begin
      for (int i=0; i<1024; i++) 
        begin
            for(int j=0; j<N; j++)
                tag_mem[i][j] = 0;
        end
    end
    
    
    assign tag_read = tag_mem[tag_req.index];
    
//    genvar i;
//      generate
//      for(i=0; i<N; i++) begin
//        assign tag_read[i] = tag_mem[tag_req.index][i];
//      end
//      endgenerate
    
    
   /*initial  begin 
        for(int k=0; k<N-1; k++)
            if(tag_req.tag == tag_mem[tag_req.index][k])
                begin
                    int dummy = k;
                    assign tag_read = tag_mem[tag_req.index][k];
                    assign way = dummy;
                end
        end*/
    
  
  
  always_ff  @(posedge(clk))  begin
    if  (tag_req.we)
      tag_mem[tag_req.index][way] <= tag_write;
  end
endmodule