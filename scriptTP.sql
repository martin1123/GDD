USE [GD1C2017]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON

/*Funcion que verifica que los horarios ingresados por parametro esten incluidos dentro del turno ingresado*/
CREATE FUNCTION [SAPNU_PUAS].[match_turn_hour]
(
	@turno int,
	@iniHour int,
	@endHour int
)
RETURNS int
AS
BEGIN
	
	DECLARE @Result  int,
			@horaini int,
			@horaFin int;

	SELECT @horaini = Turno_Hora_Inicio, @horaFin = Turno_Hora_Fin
				FROM SAPNU_PUAS.turno
		 WHERE Turno_Activo = 1
	   AND Turno_Codigo = @turno;
	
	IF(@horaini <> NULL AND @horaFin <> NULL)

	BEGIN

		IF(@iniHour >= @horaini AND @iniHour < @horaFin AND @endHour > @horaini AND @endHour <= @horaFin)
		BEGIN
			SET @Result = 1;
		END
		ELSE
		BEGIN
			SET @Result = 0;
		END;

	END

	ELSE
	BEGIN
		SET @Result = 0;
	END;

	RETURN @Result;

END;

GO

-- =======================================================================
-- Author:		Martin Maccio
-- Create date: 11/05/2017
-- Description:	Funcion que verifica que la patente recibida por parametro 
--				no exista en la tabla de Auto
-- =======================================================================
CREATE FUNCTION [SAPNU_PUAS].[verificar_patente] 
(

	@patente VARCHAR(10) 
)
RETURNS INT
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	SET @Result = (SELECT COUNT(*) 
					FROM SAPNU_PUAS.Auto
				   WHERE Auto_Patente = @patente); 


	RETURN @Result

END
;

GO
-- ==================================================================================
-- Author:		Maccio Martin
-- Create date: 09/05/2017
-- Description:	Funcion que verifica si un rango horario esta disponible en la tabla 
--              de turnos sin tener en cuenta el turno a modificar. 
--              Devuelve 0 si esta disponible, caso contrario devuelve distinto de 0.
-- ==================================================================================
CREATE FUNCTION[SAPNU_PUAS].[is_available_hour_range]
(
	@iniHour int,
	@endHour int,
	@cod     int = -1 --Parametro que toma -1 como default
)
RETURNS int
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result int

	-- Verifica si hay algun turno que se superponga con los horarios ingesados por parametro
	set @Result = (SELECT COUNT(*)
	                 FROM SAPNU_PUAS.turno
				    WHERE Turno_Activo = 1
					  AND Turno_Codigo <> @cod
					  AND ((turno_hora_inicio <= @iniHour AND  @iniHour <  turno_hora_fin)
					       OR (turno_hora_inicio <  @endHour AND  @endHour <= turno_hora_fin)
					       OR (@iniHour <= turno_hora_inicio AND turno_hora_inicio < @endHour)
					       OR (@iniHour < turno_hora_fin AND turno_hora_fin <= @endHour)))

	-- Return the result of the function
	RETURN @Result

END;


GO
-- =============================================
-- Author:		Martin Maccio
-- Create date: 09/05/2017
-- Description:	SP que da de alta un turno
-- =============================================
CREATE PROCEDURE [SAPNU_PUAS].[sp_turno_alta]
	-- Add the parameters for the stored procedure here
	@horaInicio int,
	@horaFin int,
	@descripcion varchar(255),
	@valorkm numeric(18,2),
	@precioBase numeric(18,2),
	@activo  int,
	@codOp   int OUT,
	@resultado  varchar(255) OUT
AS
BEGIN
	DECLARE @validHora int

	SET NOCOUNT ON;
	
    SET @validHora = SAPNU_PUAS.is_available_hour_range(@horaInicio,@horaFin, default);

	--Se valida que no haya ningun turno con el que se superpongan los horarios
	IF(@validHora = 0)
	BEGIN
		BEGIN TRY
			SET @codOp = 0;
			INSERT INTO SAPNU_PUAS.turno
			VALUES(@horaInicio,@horaFin,@descripcion,@valorkm,@precioBase,@activo);
		END TRY
		BEGIN CATCH
			SET @codOp = @@ERROR;

			IF(@codOp <> 0)
				SET @resultado = 'Ocurrio un error al realizar INSERT en la tabla Turnos';
		END CATCH;
	END
	ELSE
	BEGIN
	--Se encuentran turnos con horarios superpuestos, entonces se envía un mensaje indicando dicho suceso
		SET @codOp = 1;
		SET @resultado = 'Se superponen los horarios con otro/s turno/s';
	END;
END;

GO
-- =============================================
-- Author:		Martin Maccio
-- Create date: 09/05/2017
-- Description:	SP que da de alta un turno
-- =============================================
CREATE PROCEDURE [SAPNU_PUAS].[sp_turno_modif]
	-- Add the parameters for the stored procedure here
	@codigo int,
	@horaInicio int,
	@horaFin int,
	@descripcion varchar(255),
	@valorkm numeric(18,2),
	@precioBase numeric(18,2),
	@activo  int,
	@codOp   int OUT,
	@resultado  varchar(255) OUT
AS
BEGIN
	DECLARE @validHora int

	SET NOCOUNT ON;
	
	/*Se valida la hora únicamente si se va a modificar un turno que va a estar activo*/
	IF(@activo = 1)
		SET @validHora = SAPNU_PUAS.is_available_hour_range(@horaInicio,@horaFin,@codigo);
	ELSE
		SET @validHora = 0;

	--Se valida que no haya ningun turno con el que se superpongan los horarios
	IF(@validHora = 0)
	BEGIN
		BEGIN TRY
			SET @codOp = 0;
			UPDATE SAPNU_PUAS.turno
			SET Turno_Hora_Inicio = @horaInicio,
				Turno_Hora_Fin = @horaFin,
				Turno_Descripcion = @descripcion,
				Turno_Valor_Kilometro =  @valorkm,
				Turno_Precio_Base = @precioBase,
				Turno_Activo =  @activo
			WHERE Turno_codigo =  @codigo;
		END TRY
		BEGIN CATCH
			SET @codOp = @@ERROR;

			IF(@codOp <> 0)
				SET @resultado = 'Ocurrio un error al actualizar los datos de la tabla Turnos';
		END CATCH;
	END
	ELSE
	BEGIN
	--Se encuentran turnos con horarios superpuestos, entonces se envía un mensaje indicando dicho suceso
		SET @codOp = 1;
		SET @resultado = 'Se superponen los horarios con otro/s turno/s';
	END;
END;

GO
-- ==============================================================================
-- Author:		Martin Maccio
-- Create date: 11/05/2017
-- Description:	SP que realiza alta de un automovil.
--              En caso de ser exitosa el alta retorna 0, en caso contrario
--              retornara un codigo de error y un mensaje descriptivo del error.
-- ==============================================================================
CREATE PROCEDURE [SAPNU_PUAS].[sp_auto_alta] 

	@marca int, 
	@modelo varchar(255), 
	@patente varchar(10), 
	@licencia varchar(26), 
	@rodado varchar(10), 
	@activo int, 
	@chofer numeric(18,0), 
	@turno int,
	@codOp int out,
	@resultado varchar(255) out
AS
BEGIN
	DECLARE @validDuplicado int

	SET @validDuplicado = SAPNU_PUAS.verificar_patente(@patente);

	IF(@validDuplicado = 0)
	BEGIN
		BEGIN TRY
			SET @codOp = 0;
			IF(EXISTS(SELECT Auto_Chofer FROM SAPNU_PUAS.AUTO WHERE Auto_Chofer = @chofer AND Auto_Activo = 1))
			BEGIN
				SET @codOp = 2;
				SET @resultado = 'Ya existe un auto activo registrado para el chofer ingresado';
			END
			ELSE
			BEGIN
				INSERT INTO [SAPNU_PUAS].Auto
				VALUES(@marca,@modelo,@patente,@licencia,@rodado,@activo,@chofer,@turno);
			END
		END TRY
		BEGIN CATCH
			SET @codOp = @@ERROR;

			IF(@codOp <> 0)
				SET @resultado = 'Ocurrio un error al realizar INSERT en la tabla Auto';
		END CATCH
	END
	ELSE
	BEGIN
	--Se encuentra otro auto con la misma patente en la base de datos
		SET @codOp = 1;
		SET @resultado = 'Ya existe un auto con la patente ingresada. Verifique que la patente ingresada sea correcta.';
	END;

END;

GO
-- ========================================================
-- Author:		Martin Maccio
-- Create date: 11/05/2017
-- Description:	SP que realiza la modificacion de los Autos
-- ========================================================
CREATE PROCEDURE [SAPNU_PUAS].[sp_auto_modif]
	@marca int, 
	@modelo varchar(255), 
	@patente varchar(10), 
	@patente_nueva varchar(10),
	@licencia varchar(26), 
	@rodado varchar(10), 
	@activo int, 
	@chofer numeric(18,0), 
	@turno int,
	@codOp int out,
	@resultado varchar(255) out
AS
BEGIN
	DECLARE @validDuplicado int,
			@choferAutos int
	SET NOCOUNT ON;
	SET @validDuplicado = 0;

	IF(@patente <> @patente_nueva)
		SET @validDuplicado = SAPNU_PUAS.verificar_patente(@patente_nueva);

	IF(@validDuplicado = 0)
	BEGIN
		--Se verifica que un auto no tenga asignado un chofer que ya tenga un coche activo. Esta verificacion sirve en caso de que se cambie el chofer del auto.
		--Se agrega la validación contra la patente(vieja en caso de que se haya modificado por una nueva), para que se excluya de la busqueda el registro que se esta alterando. 
		IF(EXISTS(SELECT Auto_Chofer FROM SAPNU_PUAS.AUTO WHERE Auto_Chofer = @chofer AND Auto_Activo = 1 AND Auto_Patente <> @patente))
		BEGIN
			SET @codOp = 2;
			SET @resultado = 'Ya existe un auto activo registrado para el chofer ingresado';
		END
		ELSE
		BEGIN
			BEGIN TRY
				SET @codOp = 0;
				UPDATE SAPNU_PUAS.Auto
				SET Auto_Marca = @marca,
					Auto_Modelo = @modelo,
					Auto_Licencia = @licencia,
					Auto_Rodado = @rodado,
					Auto_Activo = @activo,
					Auto_Chofer = @chofer,
					Auto_turno = @turno,
					Auto_patente = @patente_nueva
				WHERE Auto_Patente =  @patente;
			END TRY
			BEGIN CATCH
				SET @codOp = @@ERROR;
		
				IF(@codOp <> 0)
					SET @resultado = 'Ocurrio un error al actualizar los datos de la tabla Auto';
			END CATCH;
		END;
	END
	ELSE
	BEGIN
	--Se encuentra otro auto con la misma patente en la base de datos
		SET @codOp = 1;
		SET @resultado = 'Ya existe un auto con la patente ingresada. Verifique que la patente ingresada sea correcta.';
	END;
END;

GO

CREATE FUNCTION [SAPNU_PUAS].[exist_car]
(
	@PATENTE varchar(10)
)
RETURNS int
AS
BEGIN
	
	RETURN (SELECT COUNT(*) 
			 FROM SAPNU_PUAS.Auto
		   WHERE Auto_Patente = @PATENTE);

END;

GO

/*Funcion que verifica la existencia de un chofer activo recibiendo su numero de telefono por parametro.*/
CREATE FUNCTION [SAPNU_PUAS].[exist_chofer]
(
	@TEL numeric(18)
)
RETURNS int
AS
BEGIN
	
	RETURN (SELECT COUNT(*) 
			 FROM SAPNU_PUAS.Chofer
		   WHERE Chofer_Activo = 1
		     AND Chofer_Telefono = @TEL);

END;

GO

CREATE FUNCTION [SAPNU_PUAS].[exist_turn]
(
	@TURNO int
)
RETURNS int
AS
BEGIN
	
	RETURN (SELECT COUNT(*) 
			 FROM SAPNU_PUAS.Turno
		   WHERE Turno_Activo = 1 
			 AND Turno_Codigo = @TURNO);

END;

GO

CREATE FUNCTION [SAPNU_PUAS].[exist_client]
(
	@CLIENT_TEL numeric(18)
)
RETURNS int
AS
BEGIN
	
	RETURN (SELECT COUNT(*) 
			 FROM SAPNU_PUAS.Cliente
		   WHERE Cliente_Telefono = @CLIENT_TEL);

END;

GO

CREATE PROCEDURE [SAPNU_PUAS].[sp_viaje_alta] 
	-- Add the parameters for the stored procedure here
	 @viaje_cant_km numeric(18), 
	 @viaje_hora_ini datetime,
	 @viaje_hora_fin datetime,
	 @viaje_chofer numeric(18),
	 @viaje_auto varchar(10),
	 @viaje_turno int,
	 @viaje_cliente numeric(18),
	 @codOp   int OUT,
	 @resultado  varchar(255) OUT
AS
BEGIN
	SET NOCOUNT ON;
	SET @codOp = 0;
	--Verifica que el viaje se realice dentro del mismo día
	IF((DATEPART(DAY, @viaje_hora_ini)) <> (DATEPART(DAY, @viaje_hora_fin)) OR (DATEPART(MONTH, @viaje_hora_ini)) <> (DATEPART(MONTH, @viaje_hora_fin)) OR (DATEPART(YEAR, @viaje_hora_ini)) <> (DATEPART(YEAR, @viaje_hora_fin)))
	BEGIN
		SET @codOp = 1;
		SET @resultado = 'La hora de inicio y fin del viaje deben corresponder al mismo día.';
	END
	ELSE IF(SAPNU_PUAS.exist_car(@viaje_auto) = 0)
	BEGIN
		SET @codOp = 2;
		SET @resultado = 'No existe un auto activo con la patente ingresada';
	END
	ELSE IF(SAPNU_PUAS.exist_chofer(@viaje_chofer) = 0)
	BEGIN
		SET @codOp = 3;
		SET @resultado = 'El chofer ingresado no se encuentra activo en el sistema';
	END
	ELSE IF(SAPNU_PUAS.exist_turn(@viaje_turno) = 0)
	BEGIN
		SET @codOp = 4;
		SET @resultado = 'No existe el turno ingresado';
	END
	ELSE IF(SAPNU_PUAS.exist_client(@viaje_cliente) = 0)
	BEGIN
		SET @codOp = 5;
		SET @resultado = 'El cliente ingresado no se encuentra registrado';
	END
	/*EN REVISION
	ELSE IF(SAPNU_PUAS.match_turn_hour(DATEPART(HOUR, @viaje_hora_ini),DATEPART(HOUR, @viaje_hora_fin),@viaje_turno) = 0)
	BEGIN
		SET @codOp = 6;
		SET @resultado = 'Los horarios ingresados no corresponden al turno elegido';
	END*/
	/*Se verifica que no exista registrado un viaje en la misma fecha y hora*/
	ELSE IF(EXISTS(SELECT * 
			 FROM SAPNU_PUAS.VIAJE A
			WHERE A.Viaje_Cliente = @viaje_cliente
		      AND (     (A.Viaje_Fecha_Hora_Inicio <= @viaje_hora_ini AND @viaje_hora_ini < A.Viaje_Fecha_Hora_Fin)
					 OR (A.Viaje_Fecha_Hora_Inicio < @viaje_hora_fin AND @viaje_hora_fin <= A.Viaje_Fecha_Hora_Fin)
				  )
				  )
		   )

	BEGIN
		SET @codOp = 7;
		SET @resultado = 'Ya se registro un viaje realizado dentro del rango horario ingresado';
	END;

	IF (@codOp = 0)
	BEGIN

		BEGIN TRY
			INSERT INTO SAPNU_PUAS.Viaje 
			VALUES (@viaje_cant_km,@viaje_hora_ini,@viaje_hora_fin,@viaje_chofer,@viaje_auto,@viaje_turno,@viaje_cliente);
		END TRY
		BEGIN CATCH

			SET @codOp = @@ERROR;

			IF(@codOp <> 0)
				SET @resultado = 'Ocurrio un error al realizar INSERT en la tabla Viaje';

		END CATCH
	END;
END;

GO

--=================================================================================
CREATE PROCEDURE SAPNU_PUAS.sp_rendicion_viajes 
-----------Autor----------------
---------Jonathan---------------

-----Declaracion de Parametros-----
	 @chofer_telefono numeric(18), 
	 @fecha datetime,
	 @turno_codigo int,
	 @porcentaje numeric(5,2),
	 @codOp   int OUT,
	 @resultado  varchar(255) OUT

AS

BEGIN

-----Declaracion de Variables-----
	DECLARE 
	@turno_precio numeric(18),
	@resultado_final numeric(18),
	@cant_kilometros numeric(18),
	@precio_base numeric(18),
	@rendicion_nro numeric(18);
    
	SET NOCOUNT ON;

--SE VERIFICA QUE NO EXISTA UNA RENDICIÓN PARA EL MISMO CHOFER EL MISMO DIA Y TURNO--
		IF(SELECT 
		count(1) 
		from SAPNU_PUAS.Rendicion
		where 
		Rendicion_Chofer = @chofer_telefono
		and CONVERT(date,Rendicion_Fecha) = CONVERT(date,@fecha)
		and Rendicion_Turno = @turno_codigo) > 0

	BEGIN
			SET @codOp = 1;
			SET @resultado = 
			'Ya existe una rendicion registrada en la misma fecha para el chofer ingresado para ese turno';
	END
	
	ELSE

		BEGIN

			--OBTENGO EL VALOR POR KILOMETRO Y EL PRECIO BASE DEL TURNO INGRESADO
			SELECT 
			@turno_precio = turno_valor_kilometro, 
			@precio_base = turno_precio_base
			FROM SAPNU_PUAS.Turno 
			WHERE 
			turno_codigo = @turno_codigo;

			--CALCULO EL VALOR FINAL DE LA RENDICION PARA ESE CHOFER EN ESE TURNO PARA ESE DIA
			SELECT 
			@resultado_final = (sum(Viaje_Cant_Kilometros * @turno_precio + @precio_base) * @porcentaje) 
			FROM SAPNU_PUAS.Viaje 
			WHERE 
			Viaje_Chofer = @chofer_telefono and 
			CONVERT(date,@fecha) = CONVERT(date,Viaje_Fecha_Hora_Inicio) and
			Viaje_Turno = @turno_codigo;

			
			BEGIN TRY
					
					SET @codOp = 0;

					BEGIN TRANSACTION T1
						
						--INSERTO LA RENDICION DE ESE CHOFER PARA ESE TURNO PARA ESE DIA
						INSERT INTO SAPNU_PUAS.Rendicion 
						(Rendicion_Fecha, Rendicion_Importe, Rendicion_Chofer, Rendicion_Turno, Rendicion_Porcentaje)
						VALUES (@fecha, @resultado_final, @chofer_telefono, @turno_codigo, @porcentaje);

						--OBTENGO EL CODIGO DE LA RENDICION RECIEN INSERTADA PARA USARLA EN EL PROXIMO INSERT
						set @rendicion_nro = @@IDENTITY;

						--INSERTO TODOS LOS VIAJES EN VIAJE X RENDICION DESDE LA TABLA DE VIAJES PARA EL CHOFER ESE DIA Y EN ESE TURNO
						INSERT INTO SAPNU_PUAS.Viaje_x_Rendicion
						SELECT Viaje_Codigo, @rendicion_nro from SAPNU_PUAS.Viaje 
						WHERE 
						Viaje_Chofer = @chofer_telefono and 
						CONVERT(date,@fecha) = CONVERT(date,Viaje_Fecha_Hora_Inicio) and
						Viaje_Turno = @turno_codigo;

					--CONFIRMO TRANSACCIONES
					COMMIT TRANSACTION T1

			END TRY
	
			BEGIN CATCH

				SET @codOp = @@ERROR;

				IF(@codOp <> 0)
				SET @resultado = 'Ocurrio un error al realizar INSERT en Rendicion/Viaje_x_Rendicion';
					--ROLLBACK DE TODAS LAS TRANSACCIONES REALIZADAS PORQUE ALGUNA FALLO
					ROLLBACK TRANSACTION T1

			END CATCH
	
		END
END;
GO

--Store Procedure de facturacion de clientes
CREATE PROCEDURE [SAPNU_PUAS].[sp_fact_cliente] 

	 @fecha_ini datetime, 
	 @fecha_fin datetime,
	 @cliente numeric(18,0),
	 @codOp   int OUT,
	 @resultado  varchar(255) OUT

AS

BEGIN


	DECLARE 
	@importe numeric(18,2),
	@precio_base numeric(18,2),
	@cant_km numeric(18,0),
	@valor_km numeric(18,2),
	@nroFact int
    
	SET NOCOUNT ON;

		--Se verifica que exista el cliente recibido por parametro
		IF(SAPNU_PUAS.exist_client(@cliente) = 0)
		BEGIN
			SET @codOp = 1;
			SET @resultado = 'No se encuentra registrado en la base de datos el cliente ingresado.';
		END
		ELSE
		
		--SI CONTROLA QUE NO EXISTA UNA FACTURACION REALIZADA EN EL MISMO MES PARA EL CLIENTE, EN CASO DE HABERLO, SE CANCELA LA FACTURACION.
		IF(EXISTS(SELECT * FROM SAPNU_PUAS.FACTURA
				   WHERE Factura_Cliente = @cliente
				     AND (Factura_Fecha_Inicio BETWEEN @fecha_ini AND @fecha_fin OR
					      Factura_Fecha_Fin    BETWEEN @fecha_ini AND @fecha_fin )))

		BEGIN
			SET @codOp = 2;
			SET @resultado = 'Ya existe una facturacion realizada para el mes ingresado. Verifique las fechas ingresadas.';
		END
	
		ELSE

		BEGIN

			--SE DECLARA CURSOR QUE RECUPERA EL IMPORTE TOTAL POR CADA TURNO
			DECLARE IMPORTES_TURNO_CURSOR CURSOR FOR
			SELECT SUM(B.Turno_Precio_Base),SUM(A.Viaje_Cant_Kilometros),b.Turno_Valor_Kilometro
			  FROM SAPNU_PUAS.Viaje A, SAPNU_PUAS.Turno B
             WHERE A.Viaje_Cliente = @cliente
               AND A.Viaje_Fecha_Hora_Inicio BETWEEN @fecha_ini AND @fecha_fin
               AND A.Viaje_Fecha_Hora_Fin    BETWEEN @fecha_ini AND @fecha_fin
               AND B.Turno_Codigo = A.Viaje_Turno
             GROUP BY A.Viaje_Turno, b.Turno_Valor_Kilometro;

			OPEN IMPORTES_TURNO_CURSOR;

			SET @importe = 0;
			FETCH NEXT FROM IMPORTES_TURNO_CURSOR INTO @precio_base, @cant_km, @valor_km
			
			--SUMA LOS IMPORTES DE CADA TURNO EN LA VARIABLE @IMPORTE
			WHILE @@FETCH_STATUS = 0  
			BEGIN  
				SET @importe = (@importe  + (@precio_base + (@cant_km * @valor_km)));
				FETCH NEXT FROM IMPORTES_TURNO_CURSOR INTO @precio_base, @cant_km, @valor_km
			END;

			CLOSE IMPORTES_TURNO_CURSOR  ;
			DEALLOCATE IMPORTES_TURNO_CURSOR  ;

			BEGIN TRY
				
				BEGIN TRANSACTION T1

				    SET @nroFact = 0;
				    	
			        SET @codOp = 0;
			        /*Se inserta la factura del mes para el cliente ingresado por parametros*/
			        INSERT INTO SAPNU_PUAS.Factura
			        VALUES (@fecha_ini,@fecha_fin,@importe,SYSDATETIME(),@cliente);
			        
			        SET @nroFact = @@IDENTITY;
				    
				    /*Si se inserto existosamente la factura, se va a insertar en la tabla VIAJE_X_FACTURA
			          la relacion entre la factura y los viajes que facturados en la misma.*/
			        INSERT INTO SAPNU_PUAS.Viaje_x_Factura
			        SELECT Factura_Nro, Viaje_Codigo FROM SAPNU_PUAS.Factura, SAPNU_PUAS.Viaje
			        WHERE Factura_nro = @nroFact
			          AND Factura_Cliente = Viaje_Cliente
                                  AND Viaje_Fecha_Hora_Inicio BETWEEN Factura_Fecha_Inicio AND Factura_Fecha_Fin
				  AND Viaje_Fecha_Hora_Fin BETWEEN Factura_Fecha_Inicio AND Factura_Fecha_Fin
			
				COMMIT TRANSACTION T1

			END TRY
			
			BEGIN CATCH
				/*Si hubo algun error se deshacen todos los cambios en las tablas*/
				ROLLBACK TRANSACTION T1;

				SET @codOp = @@ERROR;
				
				IF(@nroFact = 0)
					SET @resultado = 'Ocurrio un error al registrar la facturacion en la tabla de facturas.';
				ELSE
					SET @resultado = 'Ocurrio un error al registrar los viajes de la factura en la tabla FACTURA_X_VIAJE.';
				
			END CATCH
			    
		END;
END;
GO

CREATE FUNCTION [SAPNU_PUAS].[viajes_mas_largos](@anio int, @mes_inicio int, @mes_fin int)
RETURNS TABLE 
AS
RETURN
SELECT top 5
C.Chofer_Nombre,
C.Chofer_Apellido,
C.Chofer_Mail,
max(V.Viaje_Cant_Kilometros) AS Cant_Kms    
FROM SAPNU_PUAS.Viaje V
JOIN SAPNU_PUAS.Chofer C
ON V.Viaje_Chofer = C.Chofer_Telefono
WHERE 
YEAR(V.Viaje_Fecha_Hora_Inicio) = @anio and
MONTH(V.Viaje_Fecha_Hora_Inicio) BETWEEN @mes_inicio and @mes_fin
group by C.Chofer_Nombre, C.Chofer_Apellido, C.Chofer_Mail
order by max(V.Viaje_Cant_Kilometros) desc

GO

CREATE FUNCTION [SAPNU_PUAS].[clientes_mayor_consumo](@anio int, @mes_inicio int, @mes_fin int)
RETURNS TABLE 
AS
RETURN

select
top 5
C.Cliente_Apellido Apellido,
C.Cliente_Nombre Nombre,
C.Cliente_Mail Mail,
sum(F.Factura_Importe) as Importe


FROM SAPNU_PUAS.Factura F

INNER JOIN SAPNU_PUAS.Cliente C
ON F.Factura_Cliente = C.Cliente_Telefono

 WHERE
 YEAR(F.Factura_Fecha) = @anio and
 MONTH(F.Factura_Fecha) BETWEEN @mes_inicio and @mes_fin
 group by C.Cliente_Apellido,C.Cliente_Nombre,C.Cliente_Mail
 order by sum(F.Factura_Importe) desc

 GO

-- ========================================================
-- Author:		
-- Create date: 11/05/2017
-- Description:	SP que realiza el alta de un chofer. Si no tiene usuario,
--              se le crea uno. Caso contrario, se le asigna a su usuario
--              el rol de chofer.
-- ========================================================
CREATE PROCEDURE [SAPNU_PUAS].[sp_chofer_alta] 
	@nombre varchar(255), 
	@apellido varchar(255), 
	@dni numeric(18,0), 
	@mail varchar(50), 
	@telefono numeric(18,0), 
	@direccion varchar(255), 
	@fechaNacimiento datetime, 
	@activo tinyint,
	@codOp int out,
	@resultado varchar(255) out
AS
BEGIN

	SET @codOp = 0;
	declare @idPersona int
	
	--Chequeo si el chofer a dar de alta ya fue dado de alta como persona
	SELECT @idPersona = Persona_Id
	FROM SAPNU_PUAS.Persona P
	WHERE P.Persona_Telefono = @telefono;

	--Si no tiene persona, creo el usuario y la persona con su usuario asociado. Luego, creo el chofer con su persona
	--Caso contrario, creo el chofer y le asigno su persona
	IF (isnull(@idPersona,0) = 0)
		BEGIN
			BEGIN TRY
				INSERT INTO SAPNU_PUAS.Usuario (Usuario_Username,Usuario_Password,Usuario_Reintentos,Usuario_Activo) values (@telefono,HASHBYTES('SHA2_256',CAST(@telefono AS varchar)),0,1);
				INSERT INTO SAPNU_PUAS.Persona (Persona_Telefono,Persona_Username) values (@telefono,@telefono);
				INSERT INTO SAPNU_PUAS.Chofer (Chofer_Activo,Chofer_Apellido,Chofer_Direccion,Chofer_Dni,Chofer_Fecha_Nac,Chofer_Mail,Chofer_Nombre,Chofer_Persona,Chofer_Telefono) values (@activo,@apellido,@direccion,@dni,@fechaNacimiento,@mail,@nombre,@@IDENTITY,@telefono);
			END TRY
			BEGIN CATCH
				SET @codOp = 1;

				IF(@codOp <> 0)
					SET @resultado = 'Ocurrio un error al tratar de crear el usuario asociado al chofer';
			END CATCH
		END
	ELSE
		BEGIN TRY
			INSERT INTO SAPNU_PUAS.Chofer (Chofer_Activo,Chofer_Apellido,Chofer_Direccion,Chofer_Dni,Chofer_Fecha_Nac,Chofer_Mail,Chofer_Nombre,Chofer_Persona,Chofer_Telefono) values (@activo,@apellido,@direccion,@dni,@fechaNacimiento,@mail,@nombre,@idPersona,@telefono);
		END TRY
		BEGIN CATCH
			SET @codOp = 1;

			IF(@codOp <> 0)
				SET @resultado = 'Ocurrio un error al tratar dar de alta el chofer';
		END CATCH

	--Busco el usuario del chofer y le asigno el rol de chofer
	declare @usernameChofer varchar(50)

	BEGIN TRY
		SELECT @usernameChofer = Persona_Username
		FROM SAPNU_PUAS.Persona P
		WHERE P.Persona_Telefono = @telefono;

		INSERT INTO SAPNU_PUAS.Rol_x_Usuario (Usuario_Username,Rol_Codigo) values (@usernameChofer,(SELECT Rol_Codigo FROM Rol where Rol_Nombre = 'Chofer'));
	END TRY
	BEGIN CATCH
		SET @codOp = 1;

		IF(@codOp <> 0)
			SET @resultado = 'Ocurrio un error al tratar de asignar los permisos de chofer a su usuario';
	END CATCH

	IF (@codOp = 0)
		SET @resultado = 'Chofer creado correctamente';

END

-- ========================================================
-- Author:		
-- Create date: 11/05/2017
-- Description:	SP que realiza el alta de un cliente. Si no tiene usuario,
--              se le crea uno. Caso contrario, se le asigna a su usuario
--              el rol de Cliente.
-- ========================================================
CREATE PROCEDURE [SAPNU_PUAS].[sp_cliente_alta] 
	@nombre varchar(255), 
	@apellido varchar(255), 
	@dni numeric(18,0), 
	@mail varchar(50), 
	@telefono numeric(18,0), 
	@direccion varchar(255), 
	@fechaNacimiento datetime, 
	@codPostal numeric(4,0), 
	@activo tinyint,
	@codOp int out,
	@resultado varchar(255) out
AS
BEGIN
	
	SET @codOp = 0;

	declare @idPersona int
	
	--Chequeo si el cliente a dar de alta ya fue dado de alta como persona
	SELECT @idPersona = Persona_Id
	FROM SAPNU_PUAS.Persona P
	WHERE P.Persona_Telefono = @telefono;

	--Si no tiene persona, creo el usuario y la persona con su usuario asociado. Luego, creo el cliente con su persona
	--Caso contrario, creo el cliente y le asigno su persona
	IF (isnull(@idPersona,0) = 0)
		BEGIN
			BEGIN TRY
				INSERT INTO SAPNU_PUAS.Usuario (Usuario_Username,Usuario_Password,Usuario_Reintentos,Usuario_Activo) values (@telefono,HASHBYTES('SHA2_256',CAST(@telefono AS varchar)),0,1);
				INSERT INTO SAPNU_PUAS.Persona (Persona_Telefono,Persona_Username) values (@telefono,@telefono);
				INSERT INTO SAPNU_PUAS.Cliente (Cliente_Activo,Cliente_Apellido,Cliente_Direccion,Cliente_Dni,Cliente_Fecha_Nac,Cliente_Mail,Cliente_Nombre,Cliente_Persona,Cliente_Telefono,Cliente_Codigo_Postal) values (@activo,@apellido,@direccion,@dni,@fechaNacimiento,@mail,@nombre,@@IDENTITY,@telefono,@codPostal);
			END TRY
			BEGIN CATCH
				SET @codOp = 1;

				IF(@codOp <> 0)
					SET @resultado = 'Ocurrio un error al tratar de crear el usuario asociado al Cliente';
			END CATCH
		END
	ELSE
		BEGIN TRY
			INSERT INTO SAPNU_PUAS.Cliente (Cliente_Activo,Cliente_Apellido,Cliente_Direccion,Cliente_Dni,Cliente_Fecha_Nac,Cliente_Mail,Cliente_Nombre,Cliente_Persona,Cliente_Telefono,Cliente_Codigo_Postal) values (@activo,@apellido,@direccion,@dni,@fechaNacimiento,@mail,@nombre,@idPersona,@telefono,@codPostal);
		END TRY
		BEGIN CATCH
			SET @codOp = 1;

			IF(@codOp <> 0)
				SET @resultado = 'Ocurrio un error al tratar dar de alta el Cliente';
		END CATCH

	--Busco el usuario del Cliente y le asigno el rol de Cliente
	declare @usernameCliente varchar(50)

	BEGIN TRY
		SELECT @usernameCliente = Persona_Username
		FROM SAPNU_PUAS.Persona P
		WHERE P.Persona_Telefono = @telefono;

		INSERT INTO SAPNU_PUAS.Rol_x_Usuario (Usuario_Username,Rol_Codigo) values (@usernameCliente,(SELECT Rol_Codigo FROM Rol where Rol_Nombre = 'Cliente'));
	END TRY
	BEGIN CATCH
		SET @codOp = 1;

		IF(@codOp <> 0)
			SET @resultado = 'Ocurrio un error al tratar de asignar los permisos de Cliente a su usuario';
	END CATCH

	IF (@codOp = 0)
		SET @resultado = 'Cliente creado correctamente';

END
